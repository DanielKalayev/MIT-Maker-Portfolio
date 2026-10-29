using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine.InputSystem;
using UnityEngine;

public class GameManager : MonoBehaviour
{
    public static GameManager instance;

    [Header("Values")]
    public bool gameRunning = false;
    private string winnerPenguin;

    [Header("Maps")]
    public int forceMap = -1; //-1 for none
    public GameObject[] mapsList;
    private GameObject currentMap;
    private MapScript currentMapScript;

    [Header("Game Colors")]
    public ColorScheme[] colorSchemes;
    public Material gradientMaterial;
    public float angle;
    private int colorNum = 0;

    [Header("Penguins")]
    public Penguin[] penguins;
    public Transform penguinParent;
    public GameObject penguinTemplate;

    private Dictionary<string, GameObject> activePenguins = new Dictionary<string, GameObject>();

    readonly Dictionary<int, Vector3> SpawnOffsets = new()
    {
    { 1, new Vector3(-2,  2, 0) }, // top-left
    { 2, new Vector3( 0,  2, 0) }, // top
    { 3, new Vector3( 2,  2, 0) }, // top-right
    { 4, new Vector3(-2,  0, 0) }, // left
    { 5, new Vector3( 0,  0, 0) }, // center
    { 6, new Vector3( 2,  0, 0) }, // right
    { 7, new Vector3(-2, -2, 0) }, // bottom-left
    { 8, new Vector3( 0, -2, 0) }, // bottom
    { 9, new Vector3( 2, -2, 0) }, // bottom-right
    };

    [Header("Audio")]
    public AudioClip[] gameMusic;
    public AudioClip lobbyMusic;
    public AudioClip countdwn;

    private void Awake()
    {
        instance = this;
    }

    void Start()
    {
        SaveManager.Load();
        StartCoroutine(GameLoop());
    }
    private Sprite CreateSpriteFromTexture(Texture2D texture)
    {
        Rect rect = new Rect(0.0f, 0.0f, texture.width, texture.height);
        Vector2 pivot = new Vector2(0.5f, 0.5f);
        float pixelsPerUnit = 100.0f;

        Sprite sprite = Sprite.Create(texture, rect, pivot, pixelsPerUnit);
        return sprite;
    }

    private IEnumerator GameLoop()
    {
        yield return new WaitForSeconds(1);

        while (true)
        {
            LoadMap();

            CameraScript.instance.ResetCam(currentMapScript.CamSize);

            yield return new WaitForSeconds(1);

            LoadPenguins();

            AudioManager.instance.playMusic("LobbyMusic", lobbyMusic, 0.15f, true);

            bool placed_bet = false;

            PointSystem.instance.StartBets(() => placed_bet = true);

            while (!placed_bet)
            {
                yield return null;
            }

            yield return new WaitForSeconds(1);

            AudioManager.instance.playSFX(countdwn, transform, 1f);

            yield return new WaitForSeconds(3.5f);

            AudioManager.instance.stopMusic("LobbyMusic", false);
            AudioManager.instance.playMusic("GameMusic", randomSong(), 0.1f, true);
            BeginGame();

            while (gameRunning)
            {
                yield return null;
            }

            while (winnerPenguin == null)
            {
                yield return null;
            }

            AudioManager.instance.stopMusic("GameMusic", true);

            CameraScript.instance.WinGame(activePenguins[winnerPenguin].transform.position);

            PointSystem.instance.CollectEarnings(winnerPenguin);

            yield return new WaitForSeconds(5);

            bool showingWinScreen = true;

            WinnerScript.instance.StartWinScreen(winnerPenguin, () => showingWinScreen = false);

            while (showingWinScreen)
            {
                yield return null;
            }
        }
    }

    private AudioClip randomSong()
    {
        return gameMusic[Random.Range(0, gameMusic.Length)];
    }

    private void ResetGame()
    {
        foreach (GameObject penguin in activePenguins.Values)
        {
            Destroy(penguin);
        }
        activePenguins.Clear();
        winnerPenguin = null;
    }

    public Penguin getPengByName(string name)
    {
        for (int i = 0; i < penguins.Length; i++)
        {
            if(penguins[i].name == name) return penguins[i];
        }
        return null;
    }

    public GameObject GetPengObjByName(string name)
    {
        foreach(KeyValuePair<string, GameObject> pair in activePenguins)
        {
            if (pair.Key == name) return pair.Value;
        }
        return null;
    }

    private GameObject PickNewMap()
    {
        if (forceMap != -1)
        {
            if (currentMap != null)
            {
                Destroy(currentMap);
            }
            return mapsList[forceMap];
        }
        List<GameObject> maps = mapsList.ToList();
        if (currentMap != null)
        {
            for (int i = maps.Count - 1; i >= 0; i--)
            {
                if (currentMap.name.Contains(maps[i].name))
                {
                    maps.RemoveAt(i);
                }
            }
            Destroy(currentMap);
        }
        GameObject newMap = maps[Random.Range(0, maps.Count)];
        return newMap;
    }

    private void LoadMap()
    {
        ResetGame();
        currentMap = Instantiate(PickNewMap(), Vector3.zero, Quaternion.identity);
        MapScript script = currentMap.GetComponent<MapScript>();
        currentMapScript = script;
        currentMapScript.SetupMap();
    }

    private void LoadPenguins()
    {
        PointSystem.instance.ResetList();
        List<Penguin> pengList = penguins.ToList();
        pengList.Shuffle();
        Transform spawnPos = currentMapScript.spawnPos;

        int numOfPenguins = pengList.Count;
        if (numOfPenguins > 9) numOfPenguins = 9;

        for (int i = 0; i < numOfPenguins; i++)
        {
            string name = pengList[i].name;
            Texture2D image = pengList[i].image;
            Sprite newSprite = CreateSpriteFromTexture(image);

            GameObject newPenguin = Instantiate(penguinTemplate);
            newPenguin.name = name;
            newPenguin.GetComponent<SpriteRenderer>().sprite = newSprite;
            newPenguin.transform.parent = penguinParent;

            newPenguin.transform.position = spawnPos.position + SpawnOffsets[i + 1];

            PenguinScript script = newPenguin.GetComponent<PenguinScript>();
            script.penguinName = name;

            activePenguins.Add(name, newPenguin);
            PointSystem.instance.LoadBet(name, newSprite);
        }
    }

    private void BeginGame()
    {
        currentMapScript.ActivateMap();
        foreach (GameObject penguin in activePenguins.Values)
        {
            PenguinScript script = penguin.GetComponent<PenguinScript>();
            script.Activate();
        }
        gameRunning = true;
    }

    public void EndGame(string winnerName)
    {
        if (gameRunning)
        {
            gameRunning = false;
            currentMapScript.EndMap();
            foreach (GameObject penguin in activePenguins.Values)
            {
                PenguinScript script = penguin.GetComponent<PenguinScript>();
                script.Deactivate();
            }
            winnerPenguin = winnerName;
        }
    }

    private void CycleColors()
    {
        if (colorNum + 1 >= colorSchemes.Length)
        {
            colorNum = 0;
        }
        else
        {
            colorNum++;
        }
    }

    private void UpdColors()
    {
        ColorScheme currentColors = colorSchemes[colorNum];
        gradientMaterial.SetColor("_Color1", currentColors.color1);
        gradientMaterial.SetColor("_Color2", currentColors.color2);
        CameraScript.instance.SetBGColor(currentColors.bgColor);
    }

    private void Update()
    {
        gradientMaterial.SetFloat("_Angle", angle);

        if (Keyboard.current.shiftKey.wasPressedThisFrame)
        {
            CycleColors();
        }

        UpdColors();
    }

    #region Save and Load

    public void Save(ref PlayerSaveData data)
    {
        data.Points = PointSystem.instance.points;
    }

    public void Load(PlayerSaveData data)
    {
        PointSystem.instance.points = data.Points;
    }

    private void OnApplicationQuit()
    {
        SaveManager.Save();
    } 
    
    #endregion
}

[System.Serializable]
public struct PlayerSaveData
{
    public int Points;
}
