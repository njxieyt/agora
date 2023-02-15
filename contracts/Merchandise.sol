// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Merchandise is ERC1155, Ownable {
    constructor() ERC1155("") {}

    mapping(uint256 => string) public tokenURIs;

    function uri(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return tokenURIs[tokenId];
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount,
        string calldata newUri
    ) external onlyOwner {
        tokenURIs[tokenId] = newUri;
        _mint(to, tokenId, amount, "");
    }
}