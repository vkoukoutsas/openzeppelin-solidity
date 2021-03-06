pragma solidity ^0.4.23;

import "../ownership/Ownable.sol";
import "../ownership/rbac/RBAC.sol";
import "../ECRecovery.sol";


/**
 * @title SignatureBouncer
 * @author PhABC, Shrugs and aflesher
 * @dev Bouncer allows users to submit a signature as a permission to do an action.
 * @dev If the signature is from one of the authorized bouncer addresses, the signature
 * @dev is valid. The owner of the contract adds/removes bouncers.
 * @dev Bouncer addresses can be individual servers signing grants or different
 * @dev users within a decentralized club that have permission to invite other members.
 * @dev
 * @dev This technique is useful for whitelists and airdrops; instead of putting all
 * @dev valid addresses on-chain, simply sign a grant of the form
 * @dev keccak256(`:contractAddress` + `:granteeAddress`) using a valid bouncer address.
 * @dev Then restrict access to your crowdsale/whitelist/airdrop using the
 * @dev `onlyValidSignature` modifier (or implement your own using isValidSignature).
 * @dev
 * @dev In addition to `onlyValidSignature`, `onlyValidSignatureAndMethod` and
 * @dev `onlyValidSignatureAndData` can be used to restrict access to only a given method
 * @dev or a given method with given parameters respectively.
 * @dev
 * @dev See the tests Bouncer.test.js for specific usage examples.
 * @notice A method that uses the `onlyValidSignatureAndData` modifier must make the _sig
 * @notice parameter the "last" parameter. You cannot sign a message that has its own
 * @notice signature in it so the last 128 bytes of msg.data (which represents the
 * @notice length of the _sig data and the _sig data itself) is ignored when validating.
 * @notice Also non fixed sized parameters make constructing the data in the signature
 * @notice much more complex. See https://ethereum.stackexchange.com/a/50616 for more details.
 */
contract SignatureBouncer is Ownable, RBAC {
  using ECRecovery for bytes32;

  string public constant ROLE_BOUNCER = "bouncer";
  uint constant METHOD_ID_SIZE = 4;
  // (signature length size) 32 bytes + (signature size 65 bytes padded) 96 bytes
  uint constant SIGNATURE_SIZE = 128;

  /**
   * @dev requires that a valid signature of a bouncer was provided
   */
  modifier onlyValidSignature(bytes _sig)
  {
    require(isValidSignature(msg.sender, _sig));
    _;
  }

  /**
   * @dev requires that a valid signature with a specifed method of a bouncer was provided
   */
  modifier onlyValidSignatureAndMethod(bytes _sig)
  {
    require(isValidSignatureAndMethod(msg.sender, _sig));
    _;
  }

  /**
   * @dev requires that a valid signature with a specifed method and params of a bouncer was provided
   */
  modifier onlyValidSignatureAndData(bytes _sig)
  {
    require(isValidSignatureAndData(msg.sender, _sig));
    _;
  }

  /**
   * @dev allows the owner to add additional bouncer addresses
   */
  function addBouncer(address _bouncer)
    onlyOwner
    public
  {
    require(_bouncer != address(0));
    addRole(_bouncer, ROLE_BOUNCER);
  }

  /**
   * @dev allows the owner to remove bouncer addresses
   */
  function removeBouncer(address _bouncer)
    onlyOwner
    public
  {
    require(_bouncer != address(0));
    removeRole(_bouncer, ROLE_BOUNCER);
  }

  /**
   * @dev is the signature of `this + sender` from a bouncer?
   * @return bool
   */
  function isValidSignature(address _address, bytes _sig)
    internal
    view
    returns (bool)
  {
    return isValidDataHash(
      keccak256(address(this), _address),
      _sig
    );
  }

  /**
   * @dev is the signature of `this + sender + methodId` from a bouncer?
   * @return bool
   */
  function isValidSignatureAndMethod(address _address, bytes _sig)
    internal
    view
    returns (bool)
  {
    bytes memory data = new bytes(METHOD_ID_SIZE);
    for (uint i = 0; i < data.length; i++) {
      data[i] = msg.data[i];
    }
    return isValidDataHash(
      keccak256(address(this), _address, data),
      _sig
    );
  }

  /**
    * @dev is the signature of `this + sender + methodId + params(s)` from a bouncer?
    * @notice the _sig parameter of the method being validated must be the "last" parameter
    * @return bool
    */
  function isValidSignatureAndData(address _address, bytes _sig)
    internal
    view
    returns (bool)
  {
    require(msg.data.length > SIGNATURE_SIZE);
    bytes memory data = new bytes(msg.data.length - SIGNATURE_SIZE);
    for (uint i = 0; i < data.length; i++) {
      data[i] = msg.data[i];
    }
    return isValidDataHash(
      keccak256(address(this), _address, data),
      _sig
    );
  }

  /**
   * @dev internal function to convert a hash to an eth signed message
   * @dev and then recover the signature and check it against the bouncer role
   * @return bool
   */
  function isValidDataHash(bytes32 hash, bytes _sig)
    internal
    view
    returns (bool)
  {
    address signer = hash
      .toEthSignedMessageHash()
      .recover(_sig);
    return hasRole(signer, ROLE_BOUNCER);
  }
}
