#!/bin/bash

# Limpa o cache removendo a pasta artifacts
echo "Limpando o cache..."
rm -rf artifacts

# Compila os contratos
echo "Compilando os contratos..."
npx hardhat compile

# Executa os testes
echo "Executando os testes..."
npx hardhat test

# Mensagem final
echo "Processo concluído."