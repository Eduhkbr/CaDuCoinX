const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployFixture, mintBacked } = require("./helpers/deploy");

describe("CaDuCoinX NFT marketplace", function () {
    let owner, alice, bob, other, token, nft, marketplace;
    const price = ethers.parseUnits("100", 18);
    const fee = price * 90n / 10_000n;

    beforeEach(async function () {
        ({ owner, alice, bob, other, token, nftMarketplace: marketplace } = await deployFixture());
        const MockERC721 = await ethers.getContractFactory("MockERC721");
        nft = await MockERC721.deploy();
        await nft.waitForDeployment();
        await mintBacked(token, owner, await bob.getAddress(), ethers.parseUnits("200", 18));
    });

    async function list(tokenId, listingPrice = price) {
        await nft.mint(await alice.getAddress(), tokenId);
        await nft.connect(alice).approve(await marketplace.getAddress(), tokenId);
        await marketplace.connect(alice).listNFT(await nft.getAddress(), tokenId, listingPrice);
    }

    it("escrows the NFT and atomically pays seller and the 0.9% fee collector", async function () {
        await list(1);
        const listing = await marketplace.listings(await nft.getAddress(), 1);
        expect(listing.seller).to.equal(await alice.getAddress());
        expect(listing.price).to.equal(price);
        expect(await nft.ownerOf(1)).to.equal(await marketplace.getAddress());

        const sellerBefore = await token.balanceOf(await alice.getAddress());
        const collector = await marketplace.feeCollector();
        expect(collector).to.equal(await other.getAddress());
        const collectorBefore = await token.balanceOf(collector);
        await token.connect(bob).approve(await marketplace.getAddress(), price);
        await marketplace.connect(bob).buyNFT(await nft.getAddress(), 1);

        expect(await nft.ownerOf(1)).to.equal(await bob.getAddress());
        expect(await token.balanceOf(await alice.getAddress())).to.equal(sellerBefore + price - fee);
        expect(await token.balanceOf(collector)).to.equal(collectorBefore + fee);
        expect((await marketplace.listings(await nft.getAddress(), 1)).seller).to.equal(ethers.ZeroAddress);
    });

    it("rejects zero prices, unlisted purchases, duplicate listings, and unauthorized cancellation", async function () {
        await nft.mint(await alice.getAddress(), 2);
        await nft.connect(alice).approve(await marketplace.getAddress(), 2);
        await expect(marketplace.connect(alice).listNFT(await nft.getAddress(), 2, 0))
            .to.be.revertedWith("Price must be positive");
        await expect(marketplace.connect(bob).buyNFT(await nft.getAddress(), 2))
            .to.be.revertedWith("NFT not listed");

        await marketplace.connect(alice).listNFT(await nft.getAddress(), 2, price);
        await expect(marketplace.connect(alice).listNFT(await nft.getAddress(), 2, price))
            .to.be.revertedWith("Already listed");
        await expect(marketplace.connect(bob).cancelListing(await nft.getAddress(), 2))
            .to.be.revertedWith("Not NFT seller");
    });

    it("lets a seller update a listed price", async function () {
        await list(3);
        const newPrice = ethers.parseUnits("120", 18);
        await marketplace.connect(alice).updateListingPrice(await nft.getAddress(), 3, newPrice);
        expect((await marketplace.listings(await nft.getAddress(), 3)).price).to.equal(newPrice);
        await expect(marketplace.connect(alice).updateListingPrice(await nft.getAddress(), 3, 0))
            .to.be.revertedWith("Price must be positive");
    });

    it("rounds the 0.9% fee down to whole token units", async function () {
        await list(7, 1001n);
        const sellerBefore = await token.balanceOf(await alice.getAddress());
        const collector = await marketplace.feeCollector();
        const collectorBefore = await token.balanceOf(collector);
        await token.connect(bob).approve(await marketplace.getAddress(), 1001n);
        await marketplace.connect(bob).buyNFT(await nft.getAddress(), 7);
        expect(await token.balanceOf(await alice.getAddress())).to.equal(sellerBefore + 992n);
        expect(await token.balanceOf(collector)).to.equal(collectorBefore + 9n);
    });

    it("validates UUPS upgrades and preserves listings and ownership", async function () {
        await list(8);
        const V2 = await ethers.getContractFactory("CaDuCoinXNFTMarketplaceV2");
        const upgraded = await upgrades.upgradeProxy(await marketplace.getAddress(), V2, { kind: "uups" });
        expect(await upgraded.version()).to.equal(2);
        expect(await upgraded.owner()).to.equal(await owner.getAddress());
        expect(await upgraded.paymentToken()).to.equal(await token.getAddress());
        expect((await upgraded.listings(await nft.getAddress(), 8)).price).to.equal(price);
        expect(await nft.ownerOf(8)).to.equal(await marketplace.getAddress());
    });

    it("returns escrow during pause and rejects unsolicited safe transfers", async function () {
        await list(4);
        await token.connect(bob).approve(await marketplace.getAddress(), price);
        await marketplace.pause();
        await expect(marketplace.connect(bob).buyNFT(await nft.getAddress(), 4))
            .to.be.revertedWithCustomError(marketplace, "EnforcedPause");
        await marketplace.connect(alice).cancelListing(await nft.getAddress(), 4);
        expect(await nft.ownerOf(4)).to.equal(await alice.getAddress());
        await expect(marketplace.connect(alice).listNFT(await nft.getAddress(), 4, price))
            .to.be.revertedWithCustomError(marketplace, "EnforcedPause");

        await nft.mint(await alice.getAddress(), 5);
        await expect(nft.connect(alice).safeTransferFrom(
            await alice.getAddress(), await marketplace.getAddress(), 5
        )).to.be.revertedWith("Unsolicited NFT");
        await marketplace.unpause();
    });

    it("prevents an NFT receiver from reentering and buying a listing twice", async function () {
        await list(6);
        const ReentrantNFTBuyer = await ethers.getContractFactory("ReentrantNFTBuyer");
        const buyer = await ReentrantNFTBuyer.deploy(await marketplace.getAddress());
        await buyer.waitForDeployment();
        const buyerAddress = await buyer.getAddress();
        await mintBacked(token, owner, buyerAddress, price);
        await buyer.approvePaymentToken(await token.getAddress(), price);
        await buyer.buy(await nft.getAddress(), 6);
        expect(await buyer.reentryAttempted()).to.equal(true);
        expect(await buyer.reentrySucceeded()).to.equal(false);
        expect(await nft.ownerOf(6)).to.equal(buyerAddress);
    });
});
