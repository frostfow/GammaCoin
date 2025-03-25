// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

contract GammaCoin is ERC20, Ownable {
    string public constant LOGO_URI = "";
    
    uint256 public liquidityFee = 3;
    uint256 public marketingFee = 2;
    uint256 public reflectionFee = 2;
    uint256 public burnFee = 1;
    uint256 public totalFees = 8;
    
    address public marketingWallet;
    
    uint256 public maxTransactionAmount;
    uint256 public maxWalletAmount;
    
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public isExcludedFromLimits;
    
    bool public tradingEnabled = false;
    
    event TradingEnabled(bool enabled);
    event FeesUpdated(uint256 liquidityFee, uint256 marketingFee, uint256 reflectionFee, uint256 burnFee);
    
    constructor() ERC20("GammaCoin", "GAMMA") {
        uint256 totalSupply = 47000000 * 10**decimals();
        
        maxTransactionAmount = totalSupply * 2 / 100;
        maxWalletAmount = totalSupply * 3 / 100;
        
        marketingWallet = msg.sender;
        
        isExcludedFromFees[owner()] = true;
        isExcludedFromFees[address(this)] = true;
        isExcludedFromLimits[owner()] = true;
        isExcludedFromLimits[address(this)] = true;
        
        _mint(address(this), totalSupply * 9947 / 10000);
        _mint(owner(), totalSupply * 53 / 10000);
        _mint(0x752E9020bE761fec1d567d718dD5D932B9908935, 250000 * 10**decimals());
    }
    
    function logoURI() public pure returns (string memory) {
        return LOGO_URI;
    }
    
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
        emit TradingEnabled(true);
    }
    
    function updateFees(
        uint256 _liquidityFee,
        uint256 _marketingFee,
        uint256 _reflectionFee,
        uint256 _burnFee
    ) external onlyOwner {
        liquidityFee = _liquidityFee;
        marketingFee = _marketingFee;
        reflectionFee = _reflectionFee;
        burnFee = _burnFee;
        totalFees = _liquidityFee + _marketingFee + _reflectionFee + _burnFee;
        require(totalFees <= 25, "Total fees cannot exceed 25%");
        emit FeesUpdated(_liquidityFee, _marketingFee, _reflectionFee, _burnFee);
    }
    
    function excludeFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
    }
    
    function excludeFromLimits(address account, bool excluded) external onlyOwner {
        isExcludedFromLimits[account] = excluded;
    }
    
    function setMarketingWallet(address _marketingWallet) external onlyOwner {
        require(_marketingWallet != address(0), "Cannot set to zero address");
        marketingWallet = _marketingWallet;
    }
    
    function updateMaxTransactionAmount(uint256 newAmount) external onlyOwner {
        require(newAmount >= totalSupply() / 1000, "Max TX amount too low");
        maxTransactionAmount = newAmount;
    }
    
    function updateMaxWalletAmount(uint256 newAmount) external onlyOwner {
        require(newAmount >= totalSupply() / 1000, "Max wallet amount too low");
        maxWalletAmount = newAmount;
    }
    
    function transferFromContract(address to, uint256 amount) external onlyOwner {
        require(amount <= balanceOf(address(this)), "Insufficient contract balance");
        _transfer(address(this), to, amount);
    }
    
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }
    
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }
    
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    
    function recoverToken(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }
    
    function recoverETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        
        if (!tradingEnabled && from != owner() && to != owner()) {
            revert("Trading not yet enabled");
        }
        
        if (
            !isExcludedFromLimits[from] && 
            !isExcludedFromLimits[to] &&
            from != owner() &&
            to != owner()
        ) {
            require(amount <= maxTransactionAmount, "Transfer amount exceeds max transaction amount");
            
            if (to != address(this) && to != address(0xdead)) {
                uint256 recipientBalance = balanceOf(to);
                require(recipientBalance + amount <= maxWalletAmount, "Recipient would exceed max wallet amount");
            }
        }
        
        bool takeFee = !isExcludedFromFees[from] && !isExcludedFromFees[to];
        
        if (takeFee) {
            uint256 fees = amount * totalFees / 100;
            
            if (fees > 0) {
                super._transfer(from, address(this), fees);
                _processFees(fees);
                amount -= fees;
            }
        }
        
        super._transfer(from, to, amount);
    }
    
    function _processFees(uint256 feeAmount) internal {
        if (feeAmount == 0) return;
        
        uint256 liquidityPortion = feeAmount * liquidityFee / totalFees;
        uint256 marketingPortion = feeAmount * marketingFee / totalFees;
        uint256 reflectionPortion = feeAmount * reflectionFee / totalFees;
        uint256 burnPortion = feeAmount * burnFee / totalFees;
        
        if (marketingPortion > 0) {
            super._transfer(address(this), marketingWallet, marketingPortion);
        }
        
        if (reflectionPortion > 0 || burnPortion > 0) {
            super._transfer(address(this), address(0xdead), reflectionPortion + burnPortion);
        }
    }
    
    receive() external payable {}
}
