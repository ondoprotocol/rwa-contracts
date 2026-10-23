pragma solidity 0.8.33;

import {
  OndoSanityCheckOracle
} from "contracts/globalMarkets/tokenManager/sanityCheckOracle/OndoSanityCheckOracle.sol";

interface Vm {
  function warp(uint256) external;
}

contract OndoSanityCheckOracleTest {
  OndoSanityCheckOracle oracle;

  address admin = address(this);
  address token = address(0x2);

  function setUp() public {
    oracle = new OndoSanityCheckOracle(admin, 100, 1 days);
  }

  function testConstructorDefaults() public view {
    require(oracle.defaultDeviationBps() == 100);
    require(oracle.defaultMaxTimeDelay() == 1 days);
  }

  function testPriceNotSetReverts() public view {
    try oracle.validatePrice(token, 100e18) {
      revert("expected PriceNotSet");
    } catch (bytes memory reason) {
      bytes4 selector;
      assembly {
        selector := mload(add(reason, 32))
      }
      require(selector == OndoSanityCheckOracle.PriceNotSet.selector, "unexpected revert");
    }
  }

  function testPostZeroPriceReverts() public {
    try oracle.postPrice(token, 0) {
      revert("expected PriceNotSet");
    } catch (bytes memory reason) {
      bytes4 selector;
      assembly {
        selector := mload(add(reason, 32))
      }
      require(selector == OndoSanityCheckOracle.PriceNotSet.selector, "unexpected revert");
    }
  }

  function testPostPricesLengthMismatchReverts() public {
    address[] memory tokens = new address[](2);
    uint256[] memory prices = new uint256[](1);

    tokens[0] = token;
    tokens[1] = address(0x3);
    prices[0] = 100e18;

    try oracle.postPrices(tokens, prices) {
      revert("expected LengthMismatch");
    } catch (bytes memory reason) {
      bytes4 selector;
      assembly {
        selector := mload(add(reason, 32))
      }
      require(selector == OndoSanityCheckOracle.LengthMismatch.selector, "unexpected revert");
    }
  }

  function testPostPriceUsesDefaultConfiguration() public {
    oracle.postPrice(token, 100e18);

    (uint256 price, uint64 lastUpdated, uint32 maxTimeDelay, uint16 allowedDeviationBps) =
      oracle.prices(token);

    require(price == 100e18, "price mismatch");
    require(lastUpdated == block.timestamp, "timestamp mismatch");
    require(maxTimeDelay == 1 days, "time delay mismatch");
    require(allowedDeviationBps == 100, "deviation mismatch");
  }

  function testPerTokenConfigurationOverridesDefaults() public {
    oracle.setMaxTimeDelay(token, 2 days);
    oracle.setAllowedDeviationBps(token, 200);

    oracle.postPrice(token, 100e18);

    (uint256 price,, uint32 maxTimeDelay, uint16 allowedDeviationBps) = oracle.prices(token);

    require(price == 100e18, "price mismatch");
    require(maxTimeDelay == 2 days, "time delay override failed");
    require(allowedDeviationBps == 200, "deviation override failed");

    oracle.validatePrice(token, 102e18);
  }

  function testStalePriceReverts() public {
    oracle.postPrice(token, 100e18);

    Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    vm.warp(block.timestamp + 1 days + 1);

    try oracle.validatePrice(token, 100e18) {
      revert("expected StalePrice");
    } catch (bytes memory reason) {
      bytes4 selector;
      assembly {
        selector := mload(add(reason, 32))
      }
      require(selector == OndoSanityCheckOracle.StalePrice.selector, "unexpected revert");
    }
  }

  function testPriceOutsideDeviationReverts() public {
    oracle.postPrice(token, 100e18);

    try oracle.validatePrice(token, 102e18) {
      revert("expected PriceOutOfRange");
    } catch (bytes memory reason) {
      bytes4 selector;
      assembly {
        selector := mload(add(reason, 32))
      }
      require(selector == OndoSanityCheckOracle.PriceOutOfRange.selector, "unexpected revert");
    }
  }

  function testPostPriceAndValidate() public {
    uint256 postedPrice = 100e18;

    oracle.postPrice(token, postedPrice);

    oracle.validatePrice(token, 100.5e18);
  }
}