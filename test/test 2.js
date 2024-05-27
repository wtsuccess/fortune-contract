import hre from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs.js";
import { expect } from "chai";
import { extendEnvironment } from "hardhat/config.js";
import { BigNumber } from "ethers";


describe("Fortune", function () {
  it("let a player enter the Fortune", async function(){
    const testContract = await hre.ethers.getContractFactory("Fortune");
    const contract  = await testContract.deploy();
    const [owner, otherAccount] = await ethers.getSigners();

    const tUsdc = await hre.ethers.getContractFactory("USDC");
    const usdc = await tUsdc.deploy();

    await contract.setTokenAddress(usdc.address);

    await contract.connect(owner).setRate(5);
    expect(await contract.rate()).to.equal(BigNumber.from("5000000000000000000"));


    const transfer = BigNumber.from("100000000000000000000")
    await usdc.connect(owner).transfer(otherAccount.address, transfer);

    await usdc.connect(otherAccount).approve(contract.address, transfer);
    await contract.connect(otherAccount).enter();
    const players = await contract.players(0);
    
    expect(players).to.equal(otherAccount.address);

  });

  it("send the winner 90% of funds", async function(){
    const testContract = await hre.ethers.getContractFactory("Fortune");
    const contract  = await testContract.deploy();
    const [owner, otherAccount, wallet1, wallet2, wallet3, wallet4, wallet5, wallet6, wallet7] = await ethers.getSigners();

    const tUsdc = await hre.ethers.getContractFactory("USDC");
    const usdc = await tUsdc.deploy();

    await contract.setTokenAddress(usdc.address);

    await contract.connect(owner).setRate(5);
    expect(await contract.rate()).to.equal(BigNumber.from("5000000000000000000"));


    const transfer = BigNumber.from("5000000000000000000")

    for (let i = 0; i < 1; i++) { //adjust to number of runs for testint purposes
      await usdc.connect(owner).transfer(otherAccount.address, transfer);
      await usdc.connect(owner).transfer(wallet1.address, transfer);
      await usdc.connect(owner).transfer(wallet2.address, transfer);
      await usdc.connect(owner).transfer(wallet3.address, transfer);
      await usdc.connect(owner).transfer(wallet4.address, transfer);
      await usdc.connect(owner).transfer(wallet5.address, transfer);
      await usdc.connect(owner).transfer(wallet6.address, transfer);
      await usdc.connect(owner).transfer(wallet7.address, transfer);





      await usdc.connect(otherAccount).approve(contract.address, transfer);
      await usdc.connect(wallet1).approve(contract.address, transfer);
      await usdc.connect(wallet2).approve(contract.address, transfer);
      await usdc.connect(wallet3).approve(contract.address, transfer);
      await usdc.connect(wallet4).approve(contract.address, transfer);
      await usdc.connect(wallet5).approve(contract.address, transfer);
      await usdc.connect(wallet6).approve(contract.address, transfer);
      await usdc.connect(wallet7).approve(contract.address, transfer);






      await contract.connect(otherAccount).enter();
      await contract.connect(wallet1).enter();
      await contract.connect(wallet2).enter();
      await contract.connect(wallet3).enter();
      await contract.connect(wallet4).enter();
      await contract.connect(wallet5).enter();
      await contract.connect(wallet6).enter();
      await contract.connect(wallet7).enter();





      const player1 = await contract.players(0);
      expect(player1).to.equal(otherAccount.address);

      const player2 = await contract.players(1);
      expect(player2).to.equal(wallet1.address);







      await contract.connect(owner).pickWinner();

      console.log("Balance of the contract after winner is drawn: " + await usdc.balanceOf(contract.address));
      console.log("Balance of user1 after winner is drawn: " + await usdc.balanceOf(otherAccount.address));
      console.log("Balance of user2 after winner is drawn: " + await usdc.balanceOf(wallet1.address));
      console.log("Balance of user3 after winner is drawn: " + await usdc.balanceOf(wallet2.address));
      console.log("Balance of user4 after winner is drawn: " + await usdc.balanceOf(wallet3.address));
      console.log("Balance of user5 after winner is drawn: " + await usdc.balanceOf(wallet4.address));
      console.log("Balance of user6 after winner is drawn: " + await usdc.balanceOf(wallet5.address));
      console.log("Balance of user7 after winner is drawn: " + await usdc.balanceOf(wallet6.address));
      console.log("Balance of user8 after winner is drawn: " + await usdc.balanceOf(wallet7.address));


      //await usdc.connect(otherAccount).transfer(owner.address, await usdc.balanceOf(otherAccount.address));
      //await usdc.connect(wallet1).transfer(owner.address, await usdc.balanceOf(wallet1.address));
      //await usdc.connect(wallet2).transfer(owner.address, await usdc.balanceOf(wallet2.address));
      //await usdc.connect(wallet3).transfer(owner.address, await usdc.balanceOf(wallet3.address));


      console.log(" \n **********NEXT ROUND*******************" )
    }


  });

  it("let a user participate twice", async function(){
    const testContract = await hre.ethers.getContractFactory("Fortune");
    const contract  = await testContract.deploy();
    const [owner, otherAccount, wallet1, wallet2] = await ethers.getSigners();

    const tUsdc = await hre.ethers.getContractFactory("USDC");
    const usdc = await tUsdc.deploy();

    await contract.setTokenAddress(usdc.address);

    await contract.connect(owner).setRate(5);
    expect(await contract.rate()).to.equal(BigNumber.from("5000000000000000000"));


    const transfer = BigNumber.from("10000000000000000000")

    await usdc.connect(owner).transfer(otherAccount.address, transfer);
      
    await usdc.connect(otherAccount).approve(contract.address, transfer);
      
    await contract.connect(otherAccount).enter();
    await contract.connect(otherAccount).enter();


      const player1 = await contract.players(0);
      expect(player1).to.equal(otherAccount.address);
    
      await contract.connect(owner).pickWinner();

      console.log("Balance of the contract after winner is drawn: " + await usdc.balanceOf(contract.address));
      console.log("Balance of user1 after winner is drawn: " + await usdc.balanceOf(otherAccount.address));    
  });

  it("let a user buy multiple tickets at once", async function(){
    const testContract = await hre.ethers.getContractFactory("Fortune");
    const contract  = await testContract.deploy();
    const [owner, otherAccount,] = await ethers.getSigners();

    const tUsdc = await hre.ethers.getContractFactory("USDC");
    const usdc = await tUsdc.deploy();

    await contract.setTokenAddress(usdc.address);

    await contract.connect(owner).setRate(5);
    expect(await contract.rate()).to.equal(BigNumber.from("5000000000000000000"));

    const transfer = BigNumber.from("25000000000000000000")

    await usdc.connect(owner).transfer(otherAccount.address, transfer);
      
    await usdc.connect(otherAccount).approve(contract.address, transfer);
      
    await contract.connect(otherAccount).enterMultiple(5);


    const player1 = await contract.players(0);
    expect(player1).to.equal(otherAccount.address);

    const player2 = await contract.players(1);
    expect(player2).to.equal(otherAccount.address);

    const player3 = await contract.players(2);
    expect(player3).to.equal(otherAccount.address);
  
    await contract.connect(owner).pickWinner();
    expect(await contract.lastWinner()).to.equal(otherAccount.address);
    console.log( await usdc.balanceOf(otherAccount.address));
  });

  it("check number of tickets", async function(){
    const testContract = await hre.ethers.getContractFactory("Fortune");
    const contract  = await testContract.deploy();
    const [owner, otherAccount,] = await ethers.getSigners();

    const tUsdc = await hre.ethers.getContractFactory("USDC");
    const usdc = await tUsdc.deploy();

    await contract.setTokenAddress(usdc.address);

    await contract.connect(owner).setRate(5);
    expect(await contract.rate()).to.equal(BigNumber.from("5000000000000000000"));

    const transfer = BigNumber.from("25000000000000000000")

    await usdc.connect(owner).transfer(otherAccount.address, transfer);
      
    await usdc.connect(otherAccount).approve(contract.address, transfer);
      
    await contract.connect(otherAccount).enterMultiple(4);

    await contract.connect(otherAccount).enter();

    console.log(await contract.getBalanceOfContract());
    await contract.connect(owner).pickWinner();
    console.log(await contract.getBalanceOfContract());
  });

  it("when entering multiple times you get x + 10% tickets", async function(){
    const testContract = await hre.ethers.getContractFactory("Fortune");
    const contract  = await testContract.deploy();
    const [owner, otherAccount] = await ethers.getSigners();

    const tUsdc = await hre.ethers.getContractFactory("USDC");
    const usdc = await tUsdc.deploy();

    await contract.setTokenAddress(usdc.address);

    await contract.connect(owner).setRate(1);

    const transfer = BigNumber.from("1000000000000000000000")

    await usdc.connect(owner).transfer(otherAccount.address, transfer);
      
    await usdc.connect(otherAccount).approve(contract.address, transfer);
      
    await contract.connect(otherAccount).enterMultiple(10);
    console.log(await contract.getUserTicketsForDraw(otherAccount.address, 1));

  });

  it("Should give owner full earnings", async function(){
    const testContract = await hre.ethers.getContractFactory("Fortune");
    const contract  = await testContract.deploy();
    const [owner, otherAccount] = await ethers.getSigners();

    const tUsdc = await hre.ethers.getContractFactory("USDC");
    const usdc = await tUsdc.deploy();

    await contract.setTokenAddress(usdc.address);

    await contract.connect(owner).setRate(1);

    const transfer = BigNumber.from("1000000000000000000000")

    await usdc.connect(owner).transfer(otherAccount.address, transfer);
      
    await usdc.connect(otherAccount).approve(contract.address, transfer);
      
    await contract.connect(otherAccount).enterMultiple(5);

    await contract.connect(otherAccount).enterMultiple(20);

    console.log(await contract.getBalanceOfContract());
    await contract.connect(owner).withdrawTreasury();
    console.log(await contract.getBalanceOfContract());
    console.log(await usdc.connect(owner).balanceOf(owner.address));

  });


});