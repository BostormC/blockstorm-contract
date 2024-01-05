module.exports = async function ({ethers, deployments}) {
    const {deploy} = deployments
    const accounts = await ethers.getSigners()
    const deployer = accounts[0];

    console.log("deployer address:", deployer.address);

    let funder = "0x49843b49d0D7953C650a9a327320FfA14384F14B";
    let router = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
    let usdt = "0x55d398326f99059ff775485246999027b3197955";
    let bosReceive = "0xd741C0CA20f73CB8c214bC5c192d5f2F213c5fDE";
    let cusdReceive = "0x25c7d47c3D9DD54632AC3fA2f75FFF521102f259";
    let defInv = "0xD879c309eD55a3b84BD5831a6d9419A9e70cB8a8";


    await deploy('CusdToken', {
        from: deployer.address,
        args: [],
        log: true,
        contract: 'CusdToken',
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
        },
    })

    let cusdt = await ethers.getContract('CusdToken');
    if ((await cusdt.name()).toString()!= "CUSD" ){
        console.log("CUSD initialized");
        let cusdtinit = await cusdt.initialize(deployer.address);
        cusdtinit.wait();
    }
    console.log("CusdToken address:", cusdt.address);


    await deploy('BosToken', {
        from: deployer.address,
        args: [],
        log: true,
        contract: 'BosToken',
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
        },
    })

    let bos = await ethers.getContract('BosToken');
    console.log("BosToken address:", bos.address);


    if (await bos.name()!= "Block Storm"){
        let initBos = 
        await bos.initialize(router,cusdt.address,21000000,deployer.address,funder,deployer.address);
        await initBos.wait();
        console.log("BosToken initialize:", initBos.hash);
    }


    await deploy('BOSNFT', {
        from: deployer.address,
        args: [],
        log: true,
        contract: 'BOSNFT',
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
        },
    })

    let bosNft = await ethers.getContract('BOSNFT');
    console.log("BOSNFT address:", bosNft.address);

    if (await bosNft.name()!= "BOSNFT"){
        let bosinit = await bosNft.initialize(funder,bos.address,deployer.address);
        bosinit.wait();
        console.log("BOSNFT initialized");
    }

    console.log("BOSNFT name:", await bosNft.name());
    console.log("BOSNFT name:", await bosNft.tokenURI(1));



    await deploy('Exchange', {
        from: deployer.address,
        args: [usdt,cusdt.address,funder,deployer.address],
        log: true,
        contract: 'Exchange'
    })


    let exchange = await ethers.getContract('Exchange');
    console.log("Exchange address:", exchange.address);


    await deploy('MintPool', {
        from: deployer.address,
        args: [],
        log: true,
        contract: 'MintPool',
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
        },
    })

    let mintPool = await ethers.getContract('MintPool');
    console.log("MintPool address:", mintPool.address);



    if ((await mintPool._sellNFTRate()) == 0){
        let poolInit = await mintPool.initialize(router,cusdt.address,bos.address,bosNft.address,defInv,funder,deployer.address);
        await poolInit.wait();
        console.log("MintPool initialize:", poolInit.hash);
    }




    await deploy('BatchTransfer', {
        from: deployer.address,
        args: [],
        log: true,
        contract: 'BatchTransfer',
    })

    let batchTransfer = await ethers.getContract('BatchTransfer');
    console.log("BatchTransfer address:", batchTransfer.address)


    // let setMinPool = await bos.setMinPool(mintPool.address);
    // await setMinPool.wait();
    // console.log("bos setMinPool:", setMinPool.hash);
    //
    // await mintPool.open();
    // console.log("MintPool open:", mintPool.hash);
    // await mintPool.setNFTAddress(bosNft.address);
    // console.log("MintPool setNFTAddress:", mintPool.hash);
    //
    // await bos.setPauseGiveReward(false);
    //
    // console.log("bos setPauseGiveReward:ok");
    //
    // let watb = await mintPool.setInProject(bos.address,true);
    // watb.wait();
    //
    // console.log("MintPool setInProject:ok");
    //
    // await bosNft.setMintpool(mintPool.address);
    //
    // console.log("BOSNFT setMintpool:ok");
    //
    // await bosNft.setRewardAdmin(mintPool.address,true);
    // console.log("BOSNFT setRewardAdmin:ok");
    // await mintPool.bindInvitor("0x3226750136a5d53c93dbfd5d652042f14b82b1f4",defInv);
    // console.log("MintPool bindInvitor:ok");



    // await cusdt.approve(batchTransfer.address,"1000000000000000000000000000000000000000000000000000000000000000000000000000");
    // await bos.approve(batchTransfer.address,"100000000000000000000000000000000000000000000000000000000000000000000000000000");
    //
    //
    //
    // await cusdt.updateWhitelistEnabled(true);
    // await cusdt.updateWhitelist(batchTransfer.address,true);
    // await cusdt.updateWhitelist(deployer.address,true);
    // await cusdt.updateWhitelist(mintPool.address,true);
    // await cusdt.updateWhitelist(cusdReceive,true);
    // await mintPool.setInProject(funder,true);

    // let lp = ethers.getContractAt(cusdt, "0x7a3a780e7F711Cd87F293be7A4416C6211e1bbA0");
    // await lp.approve(batchTransfer.address,"10000000000000000000000000000000000000000000000000000000000000000000000000000000");

}

module.exports.tags = ['BosMain']