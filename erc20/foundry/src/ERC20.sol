// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";
import {IERC20Metadata} from "./extensions/IERC20Metadata.sol";
import {Context} from "./utils/Context.sol";
import {IERC20Errors} from "./interfaces/IERC20Errors.sol";

/**
 * Implementation of the {IERC20} interface.
 * 
 * This implementation is agnostic to the way tokens are created.
 * This means that a supply mechanism has to be added in a derived contract using {_mint}.
 * 
 * The default value of {decimals} is 18. To change this, you should override this function so it returns a different value. 
 * 
 * We followed general OZ contract guidelines:
 * functions revert instead returning `false` on failure. 
 * This behavior is nonetheless conventional and does not conflict with the expectations of ERC20 applications. 
 */
contract ERC20 is IERC20, IERC20Metadata, Context, IERC20Errors {

    string private _name;
    string private _symbol;

    uint256 private _totalSupply;

    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    /**
     * Sets the values for {name} and {symbol}.
     * 
     * Both values are immutable: they can only be set once during construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * Returns the name of the token
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * Returns the symbol of the token, usually a shorter version of the name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * Returns the number of decimals used to get its user representation. 
     * For eg., if `decimals` equals `2`, a balance of `505` tokens should be displayed to a user as `5.05` (`505 / 10 ** 2`).
     * 
     * Tokens usually opt for a value of 18, imitating the relationship between Ether and Wei. This is the default value returned by this function, unless its overridden.
     * 
     * NOTE: This information is only used for _display_ purposes: It in no way affects any of the arithmetic of the contract, including {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /// IERC20
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /// IERC20
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * See {IERC20-transfer}
     * 
     * Requirements:
     * - `to` cannot be a zero address
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * If `value` is the maximum `uint256`, the allowance is not updated on `transferFrom`. This is semantically equivalent to an infinite approval.
     * 
     * Requirements:
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * Skips emitting an {Approval} event indicating an allowance update. This is not required by the ERC. 
     * 
     * NOTE: Does not update the allowance if the current allowance is the maximum `uint256`. 
     * 
     * Requirements:
     * 
     * - `from` and `to` cannot be the zero address
     * - `from` must have a balance of at least `value`
     * - the caller must have allowance for `from`'s tokens of at least `value`. 
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * Moves a `value` amount of tokens from `from` to `to`.
     * 
     * This internal function is equivalent to {transfer}, and can be used to e.g. implement automatic token fees, slashing mechanisms, etc.
     * 
     * Emits a {Transfer} event.
     * 
     * Note: This function is not virtual, {update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }

        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * Transfer a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from` (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding this function.
     * 
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // overflow check required: the rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // overflow not possible: value <= fromBalance <= totalSupply
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * Variant of {_approve} with an optional flag to enable or disable the {Approval} event. 
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any `Approval` event during `transferFrom` operations.
     * 
     * Anyone who wishes to continue emitting `Approval` events on the `transferFrom` operation can force the flag to true using the following override:
     * 
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal view override {
     *  super._approve(owner, spender, value, true);
     * }
     * 
     * ```    
     *  */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * Sets `value` as the allowance of `spender` over the `owner`'s tokens. 
     * 
     * This internal function is equivalent to `approve`, and can be used to e.g. set automatic allowances for certain subsystems, etc.
     * 
     * Emits an {Approval} event.
     * 
     * Requirements:
     * 
     * - `owner` cannot be the zero address
     * - `spender` cannot be the zero address
     * 
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument. 
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * Updates `owner`'s allowance for `spender` based on spent `value`. 
     * 
     * Does not update the allowance value in case of infinite allowance. 
     * 
     * Does not emit an {Approval} event
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }

    /**
     * Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * 
     * Relies on the `_update` mechanism
     * 
     * Emits a {Transfer} event with `from` set to the zero address.
     * 
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
     function _mint(address account, uint256 value) internal {
            if (account == address(0)) {
                revert ERC20InvalidReceiver(address(0));
            }
            _update(address(0), account, value);
            
        }

    /**
     * Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     * 
     * Emits a {Transfer} event with `to` set to the zero address.
     * 
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }
}

