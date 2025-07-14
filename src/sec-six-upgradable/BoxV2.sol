// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;
import {UUPSUpgradeable} from "@oz/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@oz/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@oz/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BoxV2 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 internal number;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function setNumber(uint256 _number) external {
        number = _number;
    }

    function getNumber() external view returns (uint256) {
        return number;
    }

    function version() external pure returns (uint256) {
        return 2;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
