using System;
using AYellowpaper.SerializedCollections;
using UnityEngine;

[Serializable]
public class Penguin
{
    public string name;
    public Texture2D image;
    public Color color;
    public string desc;

    /*[SerializedDictionary("Category", "Desc")]
    public SerializedDictionary<string, string> descriptions = new SerializedDictionary<string, string>
    {
        ["Strengths"] = ""
    };*/
}
