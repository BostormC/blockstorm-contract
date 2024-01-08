module.exports = async function ({ethers, deployments}) {
    const {deploy} = deployments
    const accounts = await ethers.getSigners()
    const deployer = accounts[0];

    console.log("deployer address:", deployer.address);

    let funder = "0xD61ab6be14ee148505ab85678D8b68f072D435a8";
    let router = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
    let usdt = "0x55d398326f99059ff775485246999027b3197955";
    let bosReceive = "0xb00F40Fa13112DBE4592EcF944e900Bb953599fF";
    let defInv = "0xf5132479629408bfEC8f294917F1FEdD3990E53c";


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
        let cusdtinit = await cusdt.initialize(bosReceive,deployer.address);
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
        await bos.initialize(router,cusdt.address,21000000,bosReceive,funder,deployer.address);
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
    //
    //
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

    // let lp = ethers.getContractAt("IERC20", "0xbb9Db2DdFE61a3dc17cCeF1825701bE4767020E2");
    // await lp.approve(batchTransfer.address,"10000000000000000000000000000000000000000000000000000000000000000000000000000000");

    // let wt = await cusdt.updateWhitelistEnabled(true);
    // await wt.wait();
    // await cusdt.updateWhitelist(batchTransfer.address,true)
    // await cusdt.updateWhitelist(deployer.address,true);
    // await cusdt.updateWhitelist(mintPool.address,true);
    // await cusdt.updateWhitelist(bosReceive,true);
    // await mintPool.setInProject(funder,true);

    await run('verify:verify', {
        address: "0x2ecb8640A3c899cC61012954652788CC0670860d",
        constructorArguments: []
    });

    await run('verify:verify', {
        address: "0x05051816022D536b7A2a47e9670F70AA33a68060",
        constructorArguments: []
    });
    //
    // await run('verify:verify', {
    //     address: "0xb91Cf2f57511D0Df1dbBFA1e890DCDF822c5940f",
    //     constructorArguments: []
    // });

    // await run('verify:verify', {
    //     address: "0x7d638AA0Bd5DfB5D1165323936177b1eB205A75D",
    //     constructorArguments: []
    // });

    // await run('verify:verify', {
    //     address: exchange.address,
    //     constructorArguments: [usdt,cusdt.address,funder,deployer.address]
    // });

    // await bosNft.setRewardToken(cusdt.address);
    // await cusdt.updateWhitelist(bosNft.address,true);

    // await cusdt.updateWhitelist(router,true);
    // await cusdt.updateWhitelist("0x50a99aE63CF125aC7bFB5131130E2D93073F47f2",true);
    // await cusdt.updateWhitelist(exchange.address,true);

    // let abc = await cusdt.updateWhitelistEnabled(true);
    // await abc.wait();

    // await bos.setFeeWhiteList(mintPool.address,true);



    // await  bos.setStrictCheck(false);

    // console.log(await  bos._mainPair());
    // console.log(await bos.test11("1000000000000000000000"))


    // let abc =  await cusdt.approve(mintPool.address,"100000000000000000000000000000000000");
    // await abc.wait;



    // await mintPool.deposit("10000000000000000000","0",defInv);


    // await mintPool.setInProject(funder,true);


    // let pool = await ethers.getContractAt("Router","0x62327854A08d1C1bE479B371CdFa8533df527464");

    // address tokenA,
    //     address tokenB,
    //     uint liquidity,
    //     uint amountAMin,
    //     uint amountBMin,
    //     address to,
    //     uint deadline

     // pool.removeLiquidity("0xAbE7d77e0AAcfc74C418889289b51230e8606d7B","0xaed3f47C4dBB02d23dD668E1691F26DA3A8856fe","100000","0","0",deployer.address,"0")
}

module.exports.tags = ['BosMain']