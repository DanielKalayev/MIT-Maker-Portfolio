using UnityEngine;
using System.IO;

public class SaveManager
{
    private static SaveData saveData = new SaveData();

    [System.Serializable]
    public struct SaveData
    {
        public PlayerSaveData PlayerData;
    }

    public static string SaveFileName()
    {
        string saveFile = Application.persistentDataPath + "/save" + ".save";
        return saveFile;
    }

    public static void Save()
    {
        HandleSaveData();

        File.WriteAllText(SaveFileName(), JsonUtility.ToJson(saveData, true));
    }

    private static void HandleSaveData()
    {
        GameManager.instance.Save(ref saveData.PlayerData);
    }

    public static void Load()
    {
        string path = SaveFileName();

        if (!File.Exists(path))
        {
            Save();
            return;
        }

        string saveContent = File.ReadAllText(path);
        saveData = JsonUtility.FromJson<SaveData>(saveContent);
        HandleLoadData();
    }


    private static void HandleLoadData()
    {
        GameManager.instance.Load(saveData.PlayerData);
    }

    private string EncryptString(string plainText)
    {
        return "e";
    }
}
