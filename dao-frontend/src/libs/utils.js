export const dollarFormat = (amount) => {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
    }).format(amount)
}

export const contractAddress = process.env.NEXT_PUBLIC_CONTRACT

export const networkNameByChainId = (chainId) => {

    switch (chainId) {
        case 1:
            return "Ethereum Mainnet"
        case 5:
            return "Goerli"
        case 56:
            return "BNB Smart Chain Mainnet"
        case 97:
            return "BNB Smart Chain Testnet"
        case 137:
            return "Polygon Mainnet"
        case 80001:
            return "Mumbai"
        default:
            return "Unknown Network"
    }

}