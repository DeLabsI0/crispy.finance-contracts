// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../lib/proxy/ProxyFactory.sol";
import "./ILoanOwnerRegistry.sol";
import "./ILoan.sol";

contract LoanOwnerRegistry is ERC721, Ownable, ILoanOwnerRegistry {
    string public name;
    string public override version;
    address public immutable loanImplementation;
    mapping(ILoan => bool) public isRegisteredLoan;
    bytes32 internal immutable DOMAIN_SEPARATOR;

    constructor(
        string memory _version,
        address _loanImplementation
    )
        ERC721(
            "Crispy.finance Asset Backed Loan owner Registry",
            "CRSPY-ABLR"
        )
        Ownable()
    {
        version = _version;
        loanImplementation = _loanImplementation;

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
            bytes32(0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f),
            keccak256(bytes(name())),
            keccak256(bytes(_version)),
            chainId,
            address(this)
        ));
    }

    function createNewLoan(address _lender) external {
        ILoan newLoan = _initNewEmptyLoan(msg.sender, _lender);
        if (_lender != address(0)) {
            _safeMint(_lender, getRegistryTokenId(loan));
        }
    }

    function registerLender(address _lender) external override {
        address loan = ILoan(msg.sender);
        require(isRegisteredLoan[loan], "LOR: Not registered loan");
        uint256 tokenId = getRegistryTokenId(loan);
        _safeMint(_lender, tokenId);
    }

    function getThisLender() external view override returns(address) {
        return getLenderOf(ILoan(msg.sender));
    }

    function getLenderOf(ILoan _loan) public view returns(address) {
        uint256 tokenId = getRegistryTokenId(_loan);
        return _exists(tokenId) ? ownerOf(tokenId) : address(0);
    }

    function getRegistryTokenId(ILoan loan)
        public
        view
        override
        returns(uint256)
    {
        return uint256(
            keccak256(abi.encode(
                DOMAIN_SEPARATOR,
                address(loan)
            ))
        );
    }

    function _initNewEmptyLoan(address _lender) internal returns(ILoan newLoan) {
        newLoan = ILoan(ProxyFactory.createProxyFrom(loanImplementation));
        newLoan.init(_lender);
        isRegisteredLoan[newLoan] = true;
    }
}
