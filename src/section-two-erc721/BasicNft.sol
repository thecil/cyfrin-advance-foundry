// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract BasicNft is ERC721, Ownable {
    uint256 private s_tokenCounter;
    string private constant TOKEN_URI =
        "https://api.pudgypenguins.io/lil/image/";
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        s_tokenCounter = 1;
    }

    function mintNft() external {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenCounter++;
    }

    function tokenURI(
        uint256 tokenId
    ) public pure override returns (string memory) {
        return
            string(
                abi.encodePacked(TOKEN_URI, Strings.toString(tokenId))
            );
    }
}
