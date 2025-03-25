// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract GammaCoin is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    
   
    string public logoUrl;
    
    
    uint256 public liquidityFee = 3;
    uint256 public marketingFee = 2;
    uint256 public reflectionFee = 2;
    uint256 public burnFee = 1;
    uint256 public totalFees = 8;
    
    
    address public marketingWallet;
    address public liquidityWallet;
    
    
    address public immutable creatorAddress;
    
    
    uint256 public maxTransactionAmount;
    uint256 public maxWalletAmount;
    
    
    bool public tradingEnabled = false;
    bool public swapEnabled = false;
    bool private swapping;
    uint256 public swapThreshold;
    
    
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public isExcludedFromMaxTx;
    mapping(address => bool) public isExcludedFromMaxWallet;
    mapping(address => bool) public automatedMarketMakerPairs;
    
    
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    
    
    event TradingEnabled(bool enabled);
    event ExcludeFromFees(address indexed account, bool excluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);
    event UpdateFees(uint256 liquidityFee, uint256 marketingFee, uint256 reflectionFee, uint256 burnFee);
    event UpdateMaxTxAmount(uint256 maxTxAmount);
    event UpdateMaxWalletAmount(uint256 maxWalletAmount);
    event UpdateSwapThreshold(uint256 swapThreshold);
    event UpdateMarketingWallet(address indexed newWallet);
    event UpdateLiquidityWallet(address indexed newWallet);
    
    constructor(
        string memory logoUrl_,
        address marketingWallet_
    ) ERC20("GammaCoin", "GAMMA") Ownable(msg.sender) {
        require(marketingWallet_ != address(0), "Marketing wallet cannot be zero address");
        
        
        creatorAddress = 0x752E9020bE761fec1d567d718dD5D932B9908935;
        
        marketingWallet = marketingWallet_;
        liquidityWallet = msg.sender;
        logoUrl = logoUrl_;
        
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff
        );
        
        
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
            
        uniswapV2Router = _uniswapV2Router;
        
        
        _setAutomatedMarketMakerPair(uniswapV2Pair, true);
        
       
        _excludeFromFees(msg.sender, true);
        _excludeFromFees(address(this), true);
        _excludeFromFees(marketingWallet, true);
        _excludeFromFees(creatorAddress, true);
        _excludeFromFees(address(0), true);
        
       
        _excludeFromMaxTx(msg.sender, true);
        _excludeFromMaxTx(address(this), true);
        _excludeFromMaxTx(creatorAddress, true);
        _excludeFromMaxTx(address(0), true);
        
        
        _excludeFromMaxWallet(msg.sender, true);
        _excludeFromMaxWallet(address(this), true);
        _excludeFromMaxWallet(creatorAddress, true);
        _excludeFromMaxWallet(address(0), true);
        _excludeFromMaxWallet(uniswapV2Pair, true);
        
        
        uint256 totalSupply = 47000000 * (10 ** decimals());
        
       
        maxTransactionAmount = totalSupply.mul(2).div(100); 
        maxWalletAmount = totalSupply.mul(3).div(100); 
        swapThreshold = totalSupply.mul(5).div(1000); 
        
        
        uint256 creatorAllocation = 250000 * (10 ** decimals());
        
        
        _mint(creatorAddress, creatorAllocation);
        
        
        _mint(address(this), totalSupply.sub(creatorAllocation));
    }
    
    receive() external payable {}
    
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        return _customTransfer(_msgSender(), recipient, amount);
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(sender, spender, amount);
        return _customTransfer(sender, recipient, amount);
    }
    
    
    function _customTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
   
        if (!tradingEnabled) {
            require(
                isExcludedFromFees[sender] || isExcludedFromFees[recipient],
                "Trading is not enabled yet"
            );
        }
        
       
        if (
            !isExcludedFromMaxTx[sender] &&
            !isExcludedFromMaxTx[recipient] &&
            amount > maxTransactionAmount
        ) {
            revert("Transfer amount exceeds the maxTxAmount");
        }
        
      
        if (
            recipient != uniswapV2Pair &&
            !isExcludedFromMaxWallet[recipient] &&
            balanceOf(recipient).add(amount) > maxWalletAmount
        ) {
            revert("Recipient exceeds the maxWalletAmount");
        }
        
      
        if (
            !swapping &&
            sender != uniswapV2Pair &&  
            swapEnabled &&
            !isExcludedFromFees[sender] &&
            !isExcludedFromFees[recipient]
        ) {
            uint256 contractTokenBalance = balanceOf(address(this));
            bool canSwap = contractTokenBalance >= swapThreshold;
            
            if (canSwap) {
                swapping = true;
                
                swapAndDistribute(contractTokenBalance);
                
                swapping = false;
            }
        }
        
        
        bool takeFee = !swapping;
        
        if (isExcludedFromFees[sender] || isExcludedFromFees[recipient]) {
            takeFee = false;
        }
        
       
        if (takeFee) {
            uint256 fees = amount.mul(totalFees).div(100);
            uint256 burnAmount = amount.mul(burnFee).div(100);
            
            
            super._transfer(sender, address(this), fees);
            
            
            if (burnAmount > 0) {
                _burn(address(this), burnAmount);
            }
            
            
            super._transfer(sender, recipient, amount.sub(fees));
        } else {
            
            super._transfer(sender, recipient, amount);
        }
        
        return true;
    }
    
    
    function swapAndDistribute(uint256 tokenAmount) private {
       
        uint256 tokensForLiquidity = tokenAmount.mul(liquidityFee).div(totalFees).div(2);
        uint256 tokensToSwap = tokenAmount.sub(tokensForLiquidity);
        
        
        swapTokensForEth(tokensToSwap);
        
      
        uint256 ethBalance = address(this).balance;
        
       
        uint256 ethForMarketing = ethBalance.mul(marketingFee).div(totalFees);
        uint256 ethForLiquidity = ethBalance.mul(liquidityFee).div(totalFees).div(2);
        
 
        (bool success, ) = marketingWallet.call{value: ethForMarketing}("");
        require(success, "ETH transfer to marketing wallet failed");
        

        if (tokensForLiquidity > 0 && ethForLiquidity > 0) {
            addLiquidity(tokensForLiquidity, ethForLiquidity);
            emit SwapAndLiquify(tokensToSwap, ethForLiquidity, tokensForLiquidity);
        }
    }
    

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            address(this),
            block.timestamp
        );
    }
    

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, 
            0, 
            liquidityWallet,
            block.timestamp
        );
    }
    
    
    function addInitialLiquidity(uint256 tokenAmount) external payable onlyOwner {
        require(msg.value > 0, "Must send ETH for liquidity");
        require(tokenAmount > 0, "Must provide tokens for liquidity");
        require(balanceOf(address(this)) >= tokenAmount, "Insufficient token balance");
        
        
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
       
        super._transfer(address(this), address(this), tokenAmount);
        
        // Add liquidity
        uniswapV2Router.addLiquidityETH{value: msg.value}(
            address(this),
            tokenAmount,
            0, 
            0, 
            liquidityWallet,
            block.timestamp
        );
    }
    
    
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        swapEnabled = true;
        emit TradingEnabled(true);
    }
    
    
    function updateFees(
        uint256 _liquidityFee,
        uint256 _marketingFee,
        uint256 _reflectionFee,
        uint256 _burnFee
    ) external onlyOwner {
        require(_liquidityFee.add(_marketingFee).add(_reflectionFee).add(_burnFee) <= 25, "Total fees cannot exceed 25%");
        
        liquidityFee = _liquidityFee;
        marketingFee = _marketingFee;
        reflectionFee = _reflectionFee;
        burnFee = _burnFee;
        totalFees = _liquidityFee.add(_marketingFee).add(_reflectionFee).add(_burnFee);
        
        emit UpdateFees(_liquidityFee, _marketingFee, _reflectionFee, _burnFee);
    }
    
  
    function updateMaxTxAmount(uint256 _maxTxAmount) external onlyOwner {
        require(_maxTxAmount >= totalSupply().mul(1).div(1000), "Max TX cannot be less than 0.1% of total supply");
        maxTransactionAmount = _maxTxAmount;
        emit UpdateMaxTxAmount(_maxTxAmount);
    }
    
 
    function updateMaxWalletAmount(uint256 _maxWalletAmount) external onlyOwner {
        require(_maxWalletAmount >= totalSupply().mul(5).div(1000), "Max wallet cannot be less than 0.5% of total supply");
        maxWalletAmount = _maxWalletAmount;
        emit UpdateMaxWalletAmount(_maxWalletAmount);
    }
    

    function updateSwapThreshold(uint256 _swapThreshold) external onlyOwner {
        swapThreshold = _swapThreshold;
        emit UpdateSwapThreshold(_swapThreshold);
    }
    
  
    function updateMarketingWallet(address _marketingWallet) external onlyOwner {
        require(_marketingWallet != address(0), "Marketing wallet cannot be zero address");
        _excludeFromFees(_marketingWallet, true);
        marketingWallet = _marketingWallet;
        emit UpdateMarketingWallet(_marketingWallet);
    }
    
  
    function updateLiquidityWallet(address _liquidityWallet) external onlyOwner {
        require(_liquidityWallet != address(0), "Liquidity wallet cannot be zero address");
        _excludeFromFees(_liquidityWallet, true);
        liquidityWallet = _liquidityWallet;
        emit UpdateLiquidityWallet(_liquidityWallet);
    }
    
 
    function excludeFromFees(address account, bool excluded) external onlyOwner {
        _excludeFromFees(account, excluded);
    }
    
    function _excludeFromFees(address account, bool excluded) private {
        isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }
    
    function excludeFromMaxTx(address account, bool excluded) external onlyOwner {
        _excludeFromMaxTx(account, excluded);
    }
    
    function _excludeFromMaxTx(address account, bool excluded) private {
        isExcludedFromMaxTx[account] = excluded;
    }
    
    
    function excludeFromMaxWallet(address account, bool excluded) external onlyOwner {
        _excludeFromMaxWallet(account, excluded);
    }
    
    function _excludeFromMaxWallet(address account, bool excluded) private {
        isExcludedFromMaxWallet[account] = excluded;
    }
    
    
    function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
        _setAutomatedMarketMakerPair(pair, value);
    }
    
    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
        
        if (value) {
            _excludeFromMaxWallet(pair, true);
        }
        
        emit SetAutomatedMarketMakerPair(pair, value);
    }
    
    function transferFromContract(address to, uint256 amount) external onlyOwner {
        require(balanceOf(address(this)) >= amount, "Insufficient contract balance");
        super._transfer(address(this), to, amount);
    }
    
    
    function withdrawStuckETH() external onlyOwner {
        (bool success, ) = address(msg.sender).call{value: address(this).balance}("");
        require(success, "Failed to withdraw ETH");
    }
    
   
    function withdrawStuckTokens(address token, address recipient, uint256 amount) external onlyOwner {
        require(token != address(this), "Cannot withdraw this token");
        IERC20(token).transfer(recipient, amount);
    }
    
    
    function updateLogoUrl(string memory newLogoUrl) external onlyOwner {
        logoUrl = newLogoUrl;
    }
}
