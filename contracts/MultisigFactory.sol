// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Multisig.sol";

contract MultisigFactory {
    Multisig[] public multisigClones;

    error ZeroAddressDetected();

    function createMultisigWallet(
        uint8 _quorum,
        address[] memory _validSigners
    ) external returns (Multisig newMulsig_, uint256 length_) {
        // Perfrom sanity check
        _isZeroAddress();

        newMulsig_ = new Multisig(_quorum, _validSigners);

        multisigClones.push(newMulsig_);

        length_ = multisigClones.length;
    }

    function getMultiSigClones() external view returns (Multisig[] memory) {
        return multisigClones;
    }

    function _isZeroAddress() private view {
        require(msg.sender != address(0), ZeroAddressDetected());
    }
}
