# MIT Maker Portfolio

Hello, my name is Daniel Kalayev. This is a portfolio that showcases games and demos that were made both for fun, for friends, and because I was curious to see if I could replicate other games or projects. There are several projects in which I did not make all of the assets, but all of the code in this repository is mine and I held the programming role in every project regardless. I use both **Unity (C#)** and **Roblox Studio (Luau)** across the portfolio, and there are a total of **5** projects here for you to examine. There are a few major scripts from each project so that you don't have to browse through hundreds of different files. Thank you so much for taking the time to look over my work! 

---

## Playable Builds
You can download and play Windows executables for the completed Unity titles for the following: 
* **Go to the [Releases Tab](../../releases) on this repository** to download:
  * `In.The.Company.of.Us.zip` (horror-game)

---

Every project's purpose, functionality, cooperative partners, and extent is explained on the **SlideRoom** description, so please look at that for more info. The purpose of this is to demonstrate notable code. 

---

## Repository Folders Explanations

### 1. Penguin Bounce Simulator (`Bouncing_Penguins-game/`)
* **Engine/Language:** Unity / C#
* **Script Descriptions:**
  * **`GameManager.cs`:** This contains the main game loop of the project. This connects the data saving, points, spawns the map, the penguins, and handles most of the logic.
  * **`PointSystem.cs`:** While not being that technically complex, I experimented with different formulas to do a running calculation using events to get a point value for each penguin and I believe this script to be a good sample.
  * **`SaveManager.cs`:** This is my first attempt at saving data to a local drive for a Unity game. This script contains the functionality to load and pull data from the user's Persistent Data Path.

### 2. "In The Company Of Us" - Horror Game (`horror-game/`)
* **Engine/Language:** Unity / C#
* **Script Descriptions:**
  * **`GameManager.cs`:** Like most game managers, this script controls scene changing, game states, intro and outro sequences, and moves settings between scenes. (settings do not save on the local computer)
  * **`Monster.cs`:** The monster's (main enemy) behavior is entirely controlled in this script. It features enemy pathfinding using Unity's pathfinding. It has behavior states like chasing, idle, wandering, and angered, as well as situational events such as approaching a door that the player is in, and playing a sound queue. 
  * **`KeycardDppr.cs`:** The KeycardDoor script mainly focuses on handling behavior between the keycard and the door (no way). It utilizes many lerp functions to ease both the door and lights on the door. The reason why I've chosen to include this script specifically, is because it also multitasks checking room boundaries and affecting enemy AI. Based on where the player is on the map, there is a hitbox to check if the player is in the room, and relays that data to enemy ai.
  * **`PlayerMovement.cs`:** The player movement script is a combination of many edits from past unity first person projects combined into one. This is not the first time I'm using a version of this script, but it is the latest. It deals with vector calculation with speed and many different player states. This script was made in combination of tutorials, and very HEAVY modification of tutorials, as its origins were before I was fluent in C#, but I have completely modified a majority of the code to fit my coding style and needs.

### 3. Custom Deltarune Roblox Demo (`deltarune/`)
* **Engine/Language:** Roblox Studio / Luau
* **Script Descriptions:**
  * **`Battleserver.luau`:** Server sided script that deals with all the values, logic, and turn based actions in the battle mechanic. Its main role is to keep the battles function on the server end, and send all the clients data for each outcome.
  * **`BattleClient.luau`:** This is the client end of the battle mechanic. This script is currently very unoptimized (in my opinion) and contains over 1000 lines of code. Regardless, it was an impressive feat for me when making this game, and it syncs server and client data very well. I have planned to work on this game in the future, and optimizing this script would be one of my biggest goals.
   * **`PlayerManager.luau`:** This is a good example of Roblox Object-Oriented-Programming. Upon loading into the game, players are assigned a player data that contains plenty of stats, abilities, and data that loads on their avatar and more. Roblox usually does not natively support object-oriented-programming, so the usage of this was a valuable one for me.
   * **`PlrTemplate.luau`:** Parent "class" of `Contestants.luau`. This functions as basic OOP, and uses metatables (a roblox feature that allows for more customizable and situational lists/tables/arrays) to mimic OOP in languages like Java, C, C#, etc.
   * **`Contestants.luau`:** Child "class" of `PlrTemplate.luau`. Same logic, but different requirements. There is another class not shown in this project (it is unfinished), requiring the use of a tiered inheritence tree.

### 4. Bezier Curve Visualizer (`bezier_curve-demo/`)
* **Engine/Language:** Roblox Studio / Luau
* **Script Descriptions:**
  * **`Main.luau`:** This is a single script that functions as the demo for the visualizer. In math class, I took on a personal project (because I was intrigued) and used the vector math to make a dynamic bezier curve script. I had always used bezier curves, but finally understood them on a mathematical level to then be able to create them in another medium. I ended up showing this to the class.

### 5. Presentation Board Game (`presentation-game/`)
* **Engine/Language:** Roblox Studio / Luau
* **Script Descriptions:**
  * **`GameManager.luau`:** Main game loop script. This constantly collects slides from the clients participating, and stores them in a dictionary where at the end of the round, they will be projected on a screen. Every time a player finishes a slide, it's sent to the server, put in a list, and sent to the host's screen to count their progress as it is a timed game.
  * **`GameClient.luau`:** Client side of the game. This handles the gui that the player either draws on or types on and submits it to the server. The logic for the writing/typing was omitted because it was very messy and not up to my displaying standards. However, the functionality is discussed in the SlideRoom description.
  * **`Question.luau`:** This is a module script that the questions are created from (in instances). Sort of like objects, these can hold the different question types and this is included because I think it's a very clear and simple demonstration of script communication.
