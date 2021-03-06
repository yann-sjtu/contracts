pragma solidity >=0.5.0;

import './IPancakePair.sol';
import './IPancakeFactory.sol';
import "./SafeMath.sol";

library PancakeLibrary {
    using SafeMath for uint;
    event debugPancakeLibrary(string name);
    event debugPairAddr(bytes32 hash);
    event debugPairAddr2(address pair);
    event debugUint(uint n);
	event debugUint160(uint160 n);

   // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'PancakeLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PancakeLibrary: ZERO_ADDRESS');
    }

    function toString(bytes memory data) public pure returns(string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        emit debugPancakeLibrary("PancakeLibrary::pairFor");
        //emit debugPairAddr(keccak256(abi.encodePacked(
        //                                   hex'ff',
        //                                   factory,
        //                                   keccak256(abi.encodePacked(token0, token1)),
        //                                   hex'c6b93034ea97d931a8fae5b6eeaa11fabfdac8cd71fd4b50df6697398722e590' // init code hash just for debug
        //)));
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'1562fe258041da26bd4ce22c9dfcc73c8a7de61c1ef04880a2a7e27cc0abc4cb' // init code hash
            ))));
        emit debugPairAddr2(pair);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'1562fe258041da26bd4ce22c9dfcc73c8a7de61c1ef04880a2a7e27cc0abc4cb' // init code hash
            )))/2**96);
        emit debugPairAddr2(pair);
        emit debugPancakeLibrary("PancakeLibrary::pairFor:address");
        uint n = uint(keccak256(abi.encodePacked(
			   hex'ff',
			   factory,
			   keccak256(abi.encodePacked(token0, token1)),
			   hex'1562fe258041da26bd4ce22c9dfcc73c8a7de61c1ef04880a2a7e27cc0abc4cb' // init code hash
			)));

		emit debugUint(n);
		emit debugUint160(uint160(n/2**96));
		emit debugPairAddr(keccak256(abi.encodePacked(
           hex'ff',
           factory,
           keccak256(abi.encodePacked(token0, token1)),
           hex'1562fe258041da26bd4ce22c9dfcc73c8a7de61c1ef04880a2a7e27cc0abc4cb' // init code hash
        )));
        pair = IPancakeFactory(factory).getPair(tokenA, tokenB);
        emit debugPairAddr2(pair);
        emit debugPancakeLibrary("PancakeLibrary::pairFor:address:end");
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        emit debugPancakeLibrary("PancakeLibrary::getReserves::0");
        //pairFor(factory, tokenA, tokenB);
        emit debugPancakeLibrary("PancakeLibrary::getReserves::1");
        //(uint reserve0, uint reserve1,) = IPancakePair(pairFor(factory, tokenA, tokenB)).getReserves();
        (uint reserve0, uint reserve1,) = IPancakePair(IPancakeFactory(factory).getPair(tokenA, tokenB)).getReserves();

        emit debugPancakeLibrary("PancakeLibrary::getReserves::2");
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'PancakeLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'PancakeLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(998);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'PancakeLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(998);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal returns (uint[] memory amounts) {
        require(path.length >= 2, 'PancakeLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal returns (uint[] memory amounts) {
        require(path.length >= 2, 'PancakeLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
