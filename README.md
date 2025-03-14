# Foundry Raffle

Welcome to the **Foundry Raffle** repository! This project is a decentralized raffle system built using Foundry, leveraging powerful tools like Chainlink Automation and Chainlink VRF (Verifiable Random Function) to ensure fairness, transparency, and automation in the raffle process.

## Overview

The Foundry Raffle system is a smart contract-based raffle where participants can enter by paying an entry fee. The contract automates the selection of a winner using Chainlink VRF for randomness and Chainlink Automation to trigger the winner selection process. This ensures a secure, transparent, and trustless raffle system.

## Features

- **Chainlink VRF**: Ensures a provably fair and random selection of the winner.
- **Chainlink Automation**: Automates the winner selection process based on predefined conditions.
- **Decentralized**: Built on Ethereum, ensuring transparency and immutability.
- **Entry Fee**: Participants must pay a fixed entry fee to join the raffle.
- **Winner Selection**: The contract automatically selects a winner and transfers the prize pool to the winner's address.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Foundry](https://getfoundry.sh/)
- [Node.js](https://nodejs.org/)
- [MetaMask](https://metamask.io/) or any Ethereum wallet

## Installation

1. **Clone the repository:**

   ```bash
   git clone https://github.com/Prince-PT/foundry-raffle.git
   cd foundry-raffle
   ```

2. **Install dependencies:**

   ```bash
   forge install
   ```

3. **Set up environment variables:**

   Create a `.env` file in the root directory and add the following variables:

   ```bash
   PRIVATE_KEY=your_private_key
   RPC_URL=your_ethereum_rpc_url
   ETHERSCAN_API_KEY=your_etherscan_api_key
   ```

4. **Compile the contracts:**

   ```bash
   forge build
   ```

## Usage

### Deploying the Contract

To deploy the raffle contract, run the following command:

```bash
forge create --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> src/Raffle.sol:Raffle --constructor-args <ENTRY_FEE> <INTERVAL> <VRF_COORDINATOR> <LINK_TOKEN> <KEY_HASH> <SUBSCRIPTION_ID>
```

Replace the placeholders with the appropriate values:

- `<RPC_URL>`: Your Ethereum node RPC URL.
- `<PRIVATE_KEY>`: Your wallet's private key.
- `<ENTRY_FEE>`: The entry fee for the raffle in wei.
- `<INTERVAL>`: The time interval (in seconds) between raffle rounds.
- `<VRF_COORDINATOR>`: The address of the Chainlink VRF Coordinator.
- `<LINK_TOKEN>`: The address of the LINK token.
- `<KEY_HASH>`: The key hash for the Chainlink VRF.
- `<SUBSCRIPTION_ID>`: Your Chainlink VRF subscription ID.

### Entering the Raffle

Participants can enter the raffle by calling the `enterRaffle` function and sending the required entry fee.

### Selecting the Winner

The winner selection process is automated using Chainlink Automation. Once the conditions are met (e.g., time interval has passed and there are participants), the contract will automatically request a random number from Chainlink VRF and select a winner.

### Withdrawing Funds

The contract owner can withdraw the funds from the contract using the `withdraw` function.

## Testing

To run the tests, use the following command:

```bash
forge test
```

## Contributing

Contributions are welcome! If you have any suggestions, bug reports, or feature requests, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

## Acknowledgments

- Cyfrin Updraft for their incredible support and resources that made this project possible.
- Patrick Collins for his amazing tutorials and guidance in the blockchain space.
- [Foundry](https://getfoundry.sh/) for the development framework.
- [Chainlink](https://chain.link/) for providing VRF and Automation services.
- The Ethereum community for their continuous support and innovation.

## Contact

If you have any questions or need further assistance, feel free to reach out:

- **Prince PT**
- GitHub: [Prince-PT](https://github.com/Prince-PT)
- Email: [thakkarprince100@gmail.com]

---

Thank you for checking out the Foundry Raffle project! We hope you find it useful and interesting. Happy coding! 🚀