#!/usr/bin/env node

const Wallet = require('ethereumjs-wallet').default;
const fs = require('fs');
const readline = require('readline');
const path = require('path');

// Create readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Generate a random wallet
function generateRandomWallet() {
  const wallet = Wallet.generate();
  return {
    address: wallet.getAddressString(),
    privateKey: wallet.getPrivateKeyString()
  };
}

// Save wallet to file with custom filename
function saveWallet(wallet, filename) {
  // Ensure the filename has a .json extension
  if (!filename.endsWith('.json')) {
    filename += '.json';
  }
  
  // Create the full path
  const filePath = path.resolve(process.cwd(), filename);
  
  try {
    fs.writeFileSync(filePath, JSON.stringify(wallet, null, 2));
    console.log(`Wallet saved to ${filePath}`);
    return true;
  } catch (error) {
    console.error(`Error saving wallet: ${error.message}`);
    return false;
  }
}

// Generate a paper wallet HTML file
function generatePaperWallet(wallet, filename) {
  if (!filename.endsWith('.html')) {
    filename += '.html';
  }
  
  const filePath = path.resolve(process.cwd(), filename);
  
  const html = `
<!DOCTYPE html>
<html>
<head>
  <title>Ethereum Paper Wallet</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
    .wallet { border: 2px solid #000; padding: 20px; margin: 20px auto; max-width: 800px; }
    .warning { color: red; font-weight: bold; }
    .address, .private { font-family: monospace; font-size: 14px; word-break: break-all; background: #f5f5f5; padding: 10px; border-radius: 4px; }
    h1 { text-align: center; }
    .section { margin-bottom: 20px; }
  </style>
</head>
<body>
  <div class="wallet">
    <h1>Ethereum Paper Wallet</h1>
    <p class="warning">IMPORTANT: Keep this document in a secure location. Anyone with access to the private key can access your funds.</p>
    
    <div class="section">
      <h2>Public Address:</h2>
      <p class="address">${wallet.address}</p>
    </div>
    
    <div class="section">
      <h2>Private Key (SECRET!):</h2>
      <p class="private">${wallet.privateKey}</p>
    </div>
    
    <div class="section">
      <p>Generated on: ${new Date().toLocaleString()}</p>
    </div>
  </div>
</body>
</html>
  `;
  
  try {
    fs.writeFileSync(filePath, html);
    console.log(`Paper wallet saved to ${filePath}`);
    return true;
  } catch (error) {
    console.error(`Error saving paper wallet: ${error.message}`);
    return false;
  }
}

// Main menu
function showMenu() {
  console.log('\n===== Ethereum Wallet Generator =====');
  console.log('1. Generate a single wallet');
  console.log('2. Generate multiple wallets');
  console.log('3. Exit');
  
  rl.question('\nEnter your choice (1-3): ', (choice) => {
    switch(choice) {
      case '1':
        const wallet = generateRandomWallet();
        console.log('\nWallet generated:');
        console.log(`Address: ${wallet.address}`);
        console.log(`Private Key: ${wallet.privateKey}`);
        
        rl.question('\nSave to file? (y/n): ', (answer) => {
          if (answer.toLowerCase() === 'y') {
            rl.question('Enter filename (default: wallet.json): ', (filename) => {
              const fname = filename.trim() || 'wallet.json';
              saveWallet(wallet, fname);
              
              rl.question('Generate paper wallet? (y/n): ', (paperAnswer) => {
                if (paperAnswer.toLowerCase() === 'y') {
                  const paperFilename = fname.replace('.json', '') + '-paper.html';
                  generatePaperWallet(wallet, paperFilename);
                }
                showMenu();
              });
            });
          } else {
            showMenu();
          }
        });
        break;
        
      case '2':
        rl.question('\nHow many wallets do you want to generate? ', (count) => {
          const numWallets = parseInt(count);
          if (isNaN(numWallets) || numWallets <= 0) {
            console.log('Please enter a valid number.');
            showMenu();
            return;
          }
          
          console.log(`\nGenerating ${numWallets} wallets...`);
          
          const wallets = [];
          for (let i = 0; i < numWallets; i++) {
            const wallet = generateRandomWallet();
            wallets.push(wallet);
            console.log(`\nWallet ${i + 1}:`);
            console.log(`Address: ${wallet.address}`);
            console.log(`Private Key: ${wallet.privateKey.substring(0, 10)}...`);
          }
          
          rl.question('\nSave wallets to file? (y/n): ', (answer) => {
            if (answer.toLowerCase() === 'y') {
              rl.question('Enter filename (default: wallets.json): ', (filename) => {
                const fname = filename.trim() || 'wallets.json';
                
                try {
                  fs.writeFileSync(fname, JSON.stringify(wallets, null, 2));
                  console.log(`Wallets saved to ${fname}`);
                } catch (error) {
                  console.error(`Error saving wallets: ${error.message}`);
                }
                
                showMenu();
              });
            } else {
              showMenu();
            }
          });
        });
        break;
        
      case '3':
        console.log('\nExiting. Goodbye!');
        rl.close();
        break;
        
      default:
        console.log('\nInvalid choice. Please try again.');
        showMenu();
    }
  });
}

// Start the program
console.log('\n⚠️  SECURITY WARNING ⚠️');
console.log('This tool generates Ethereum wallet keys.');
console.log('Keep your private keys secure and never share them.');
console.log('For maximum security, run this on an offline computer.');

showMenu();

rl.on('close', () => {
  process.exit(0);
});
