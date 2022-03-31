from brownie import accounts, ShojiVault, Shojiru, ShojiruFarm, StratShojiru, AutoShojiru, interface
import time

def main():

prod = True # change this when deploying

# params
publish = True if prod else False
acct = accounts.load("telos_yo", password="Societe") if prod else accounts[0]
treasury = acct
keeper = acct
platform = acct

# Zappy addresses
router = interface.IPancakeRouter02("0xB9239AF0697C8efb42cBA3568424b06753c6da71")

zappy = interface.IBEP20("0x9A271E3748F59222f5581BaE2540dAa5806b3F77") # Cake on Telos
chef = interface.IFarm("0x3D2c6bCED5f50f5412234b87fF0B445aBA4d10e9") # producer of Zappy - cake

wtlos = interface.IBEP20("0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E")
    
    # token Shojiru
    shojiru = Shojiru.deploy({"from":acct})

    # premint to add liquidity
    shojiru.grantMinterRole(acct)
    shojiru.mint(acct, 1_000_000e18)

    # adding liquidity to Zappy
    shojiru.approve(router, 1_000_000e18)
    # router.addLiquidityETH(shojiru,
    #                 1_000e18,
    #                 0,
    #                 0,
    #                 acct,
    #                 int(time.time()+1000),
    #                 {"from":acct, "value":1e18}
    #                 )

    # factory = interface.IPancakeFactory(router.factory())

    # sjr_tlos_lp = interface.IPancakePair(factory.getPair(wtlos, shojiru))
    
    # # farming contract that manages the mint
    # farm = ShojiruFarm.deploy(
    #                 shojiru, # farmed token
    #                 0)        # start block)

    # # We give the ownership of the token to the farm contract
    # shojiru.grantMinterRole(farm)

    # # Contract used to store the Shojiru staked and linked to the farm
    # staking_sjr = StratShojiru.deploy(
    #                                 shojiru,    # token
    #                                 farm,       # farm contract
    #                                 acct)       # governor
    
    # # We can now deploy the Auto Shojiru vault
    # auto_sjr = AutoShojiru.deploy(
    #                             shojiru, # token
    #                             farm,    # farm contract
    #                             acct)    # owner

    # # Finally we deploy the SweetVault, which is the entrance point
    # shojiVault = ShojiVault.deploy(
    #             shojiru,    # _shojiru,
    #             auto_sjr,    # _autoShojiru,
    #             "0x774d427B2105849A0FBb6f49c432C087E3607F6F", # _stakedToken (zappy-tlos lp)
    #             chef,    # _stakedTokenFarm,
    #             zappy,    # _farmRewardToken,
    #             0,    # _farmPid,
    #             False,    # _isCakeStaking,
    #             router,    # _router,
    #             [shojiru, wtlos],    # _pathToShojiru,
    #             [wtlos, shojiru],   # _pathToWtlos,
    #             acct,    # _owner,
    #             treasury,    # _treasury,
    #             keeper,    # _keeper,
    #             platform,    # _platform,
    #             300,    # _buyBackRate,
    #             500    # _platformFee
    # )

# Scanned farm :  0x3D2c6bCED5f50f5412234b87fF0B445aBA4d10e9
# 9 pools available
# ----------------------------------------------------
# Pool:           0
# LP token name   Zappy LP
# LP address      0x774d427B2105849A0FBb6f49c432C087E3607F6F
# alloc points    300
 
# Token0:         0x9A271E3748F59222f5581BaE2540dAa5806b3F77      Zappy
# Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
# ----------------------------------------------------
# Pool:           1
# LP token name   Zappy LP
# LP address      0xeA96c8d2FFA10FFeF65a87C957C27114051336F4
# alloc points    90
 
# Token0:         0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b      USD Coin
# Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
# ----------------------------------------------------
# Pool:           2
# LP token name   Zappy LP
# LP address      0xA8A2ccbD5B130bd965Dc2C24fc8938AEa7493216
# alloc points    44
 
# Token0:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
# Token1:         0xfA9343C3897324496A05fC75abeD6bAC29f8A40f      Ethereum
# ----------------------------------------------------
# Pool:           3
# LP token name   Zappy LP
# LP address      0x2C3dd9b87f5EcD49F6AE3566a5d61D8Ea6Dc21c2
# alloc points    35
 
# Token0:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
# Token1:         0xf390830DF829cf22c53c8840554B98eafC5dCBc2      Wrapped BTC
# ----------------------------------------------------
# Pool:           4
# LP token name   Zappy LP
# LP address      0x06754b2a38782AA5c9B071Dc70A5C49457C7eBD1
# alloc points    30
 
# Token0:         0x332730a4F6E03D9C55829435f10360E13cfA41Ff      Matic
# Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
# ----------------------------------------------------
# Pool:           5
# LP token name   Zappy LP
# LP address      0x8DFb20737aF995F78fAa5eB0349a7766EE3a543E
# alloc points    30
 
# Token0:         0x7C598c96D02398d89FbCb9d41Eab3DF0C16F227D      Avalanche
# Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
# ----------------------------------------------------
# Pool:           6
# LP token name   Zappy LP
# LP address      0xa58615cB042e2ba96c8bef072aad256c15aC8372
# alloc points    42
 
# Token0:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
# Token1:         0xeFAeeE334F0Fd1712f9a8cc375f427D9Cdd40d73      Tether USD
# ----------------------------------------------------
# Pool:           7
# LP token name   Zappy LP
# LP address      0x65980727179035C6A10dC5d79057B842e893627c
# alloc points    30
 
# Token0:         0x2C78f1b70Ccf63CDEe49F9233e9fAa99D43AA07e      Binance
# Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
# ----------------------------------------------------
# Pool:           8
# LP token name   Zappy LP
# LP address      0x62514Ad55D9fbb7eA66a915a1A1E11872F5FAA90
# alloc points    30
 
# Token0:         0xC1Be9a4D5D45BeeACAE296a7BD5fADBfc14602C4      Fantom
# Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS