const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployFixture } = require("./helpers/deploy");

describe("CaDuCoinXToken NFT escrow marketplace", function () {
    let owner, alice, bob, token, nft, tokenAddress, nftAddress;
    const price = ethers.parseUnits("10", 18);

    beforeEach(async function () {
        ({ owner, alice, bob, token } = await deployFixture());
        tokenAddress = await token.getAddress();

        const MockERC721 = await ethers.getContractFactory("MockERC721");
        nft = await MockERC721.deploy();
        await nft.waitForDeployment();
        nftAddress = await nft.getAddress();

        await token.mint(await alice.getAddress(), ethers.parseUnits("100", 18));
        await token.mint(await bob.getAddress(), ethers.parseUnits("100", 18));
    });

    async function list(tokenId, listingPrice = price) {
        await nft.mint(await alice.getAddress(), tokenId);
        await nft.connect(alice).approve(tokenAddress, tokenId);
        await token.connect(alice).listNFT(nftAddress, tokenId, listingPrice);
    }

    it("escrows a seller-owned NFT at a positive fixed price and pays the seller", async function () {
        await list(1);
        const listing = await token.nftListings(nftAddress, 1);
        expect(listing.seller).to.equal(await alice.getAddress());
        expect(listing.price).to.equal(price);
        expect(await nft.ownerOf(1)).to.equal(tokenAddress);

        const aliceBefore = await token.balanceOf(await alice.getAddress());
        const bobBefore = await token.balanceOf(await bob.getAddress());
        await token.connect(bob).buyNFT(nftAddress, 1);

        expect(await nft.ownerOf(1)).to.equal(await bob.getAddress());
        expect(await token.balanceOf(await alice.getAddress())).to.equal(aliceBefore + price);
        expect(await token.balanceOf(await bob.getAddress())).to.equal(bobBefore - price);
        expect((await token.nftListings(nftAddress, 1)).seller).to.equal(ethers.ZeroAddress);
    });

    it("rejects zero-price listings, unlisted purchases, and unauthorized cancellation", async function () {
        await nft.mint(await alice.getAddress(), 2);
        await nft.connect(alice).approve(tokenAddress, 2);
        await expect(token.connect(alice).listNFT(nftAddress, 2, 0))
            .to.be.revertedWith("Price must be positive");
        await expect(token.connect(bob).buyNFT(nftAddress, 2)).to.be.revertedWith("NFT not listed");

        await token.connect(alice).listNFT(nftAddress, 2, price);
        await expect(token.connect(bob).cancelNFTListing(nftAddress, 2))
            .to.be.revertedWith("Not NFT seller");
    });

    it("returns escrow to the seller on cancellation, including while paused", async function () {
        await list(3);
        await token.pause();
        await token.connect(alice).cancelNFTListing(nftAddress, 3);

        expect(await nft.ownerOf(3)).to.equal(await alice.getAddress());
        expect((await token.nftListings(nftAddress, 3)).seller).to.equal(ethers.ZeroAddress);
        await expect(token.connect(bob).buyNFT(nftAddress, 3))
            .to.be.revertedWithCustomError(token, "EnforcedPause");
        await token.unpause();
        await expect(token.connect(bob).buyNFT(nftAddress, 3)).to.be.revertedWith("NFT not listed");
    });

    it("rejects unsolicited safe transfers of NFTs", async function () {
        await nft.mint(await alice.getAddress(), 4);
        await expect(nft.connect(alice).safeTransferFrom(await alice.getAddress(), tokenAddress, 4))
            .to.be.revertedWith("Unsolicited NFT");
    });

    it("prevents an NFT receiver from reentering and buying the same listing twice", async function () {
        await list(5);
        const ReentrantNFTBuyer = await ethers.getContractFactory("ReentrantNFTBuyer");
        const buyer = await ReentrantNFTBuyer.deploy(tokenAddress);
        await buyer.waitForDeployment();
        const buyerAddress = await buyer.getAddress();
        await token.mint(buyerAddress, price);

        await buyer.buy(nftAddress, 5);

        expect(await buyer.reentryAttempted()).to.equal(true);
        expect(await buyer.reentrySucceeded()).to.equal(false);
        expect(await nft.ownerOf(5)).to.equal(buyerAddress);
        expect((await token.nftListings(nftAddress, 5)).seller).to.equal(ethers.ZeroAddress);
    });
});
