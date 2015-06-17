echo "Setup Py-Ethereum to the 'pyethereum' directory"
if [ -d "pyethereum" ]; then
   echo Found previous installation directory. 
   echo Attempt to remove...
   sudo rm -r pyethereum
fi
git clone https://github.com/ethereum/pyethereum/
cd pyethereum
sudo pip install -r requirements.txt
