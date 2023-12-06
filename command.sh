#!/bin/bash

echo "Select an action:"
echo "1. Check balances"
echo "2. Compile"
echo "3. Deploy"
echo "4. Flatten contract"
echo "5. AddingAUniversalReceiverDelegate script"
echo "6. CallingFunctionOnDeployedContract script"
echo "7. CCTX"
echo "8. Run tests"
echo "9. Exit"

read choice

case $choice in
  1)
    echo "Fetching balances"
    npx hardhat balances
    ;;
  2)
    echo "Compiling contracts..."
    npx hardhat compile 
    ;;
  3)
    echo "Executing deploy script"
    echo "Script path: scripts/deploy.ts"
    npx hardhat run scripts/deploy.ts --network luksoTestnet
    ;;
  4)
    echo "Select a contract to flatten:"
    echo "1. USDCToken.sol"
    echo "2. ERA.sol"
    echo "3. ERAHomiNft.sol"
    echo "4. UniversalReceiverDelegate.sol"
    read contract_choice

    case $contract_choice in
      1)
        contract_filename="MyToken.sol"
        output_filename="MyToken.txt"
        ;;
      2)
        contract_filename="ERA.sol"
        output_filename="ERA.txt"
        ;;
      3)
        contract_filename="ERAHomiNft.sol"
        output_filename="ERAHomiNft.txt"
        ;;
      4)
        contract_filename="UniversalReceiverDelegate.sol"
        output_filename="UniversalReceiverDelegate.txt"
        ;;
      *)
        echo "Invalid contract choice"
        exit 1
        ;;
    esac

    echo "Flattening contract $contract_filename to $output_filename"
    npx hardhat flatten contracts/"$contract_filename" > Verify/"$output_filename"
    ;;
  5)
    echo "Executing AddingAUniversalReceiverDelegate script"
    echo "Script path: scripts/AddingAUniversalReceiverDelegate.ts"
    npx hardhat run scripts/AddingAUniversalReceiverDelegate.ts --network luksoTestnet
    ;;
  6)
    echo "Executing CallingFunctionOnDeployedContract script"
    echo "Script path: scripts/CallingFunctionOnDeployedContract.ts"
    npx hardhat run scripts/CallingFunctionOnDeployedContract.ts --network luksoTestnet
    ;;
  7)
    echo "Enter the transaction hash:"
    read tx_hash
    echo "Executing CCTX with transaction hash: $tx_hash"
    npx hardhat cctx --tx "$tx_hash"
    ;;
  8)
    echo "Running tests"
    npx hardhat test
    ;;
  9)
    echo "Exiting script"
    exit 0
    ;;
  *)
    echo "Invalid choice: $choice"
    ;;
esac