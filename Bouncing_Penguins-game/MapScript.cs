using UnityEngine;

public class MapScript : MonoBehaviour
{
    [Header("Main")]
    public Transform spawnPos;
    public GameObject spawnBarrier;
    public float CamSize = 16f;

    [Header("Objectives")]
    public GameObject[] coins;

    [Header("Obstacles")]
    public GameObject[] obstacles;

    bool showSpawn = false;

    void Start()
    {
        if (!showSpawn)
        {
            spawnPos.GetComponent<SpriteRenderer>().enabled = false;
        }
    }

    public void SetupMap()
    {
        int coinNum = Random.Range(0, coins.Length);
        for (int i = 0; i < coins.Length; i++)
        {
            CoinScript coinScript = coins[i].GetComponent<CoinScript>();
            coinScript.realCoin = (i == coinNum);
        }
    }

    public void ActivateMap()
    {
        foreach (var coin in coins)
        {
            coin.GetComponent<CoinScript>().Activate();
        }

        foreach (var obstacle in obstacles)
        {
            if (obstacle.transform.GetComponent<SpinnyObject>())
            {
                obstacle.transform.GetComponent<SpinnyObject>().Toggle(true);
            }
        }

        Destroy(spawnBarrier.gameObject);
    }

    public void EndMap()
    {
        for (int i = 0; i < coins.Length; i++)
        {
            CoinScript coinScript = coins[i].GetComponent<CoinScript>();
            coinScript.Deactivate();
        }

        foreach (var obstacle in obstacles)
        {
            if (obstacle.transform.GetComponent<SpinnyObject>())
            {
                obstacle.transform.GetComponent<SpinnyObject>().Toggle(false);
            }
        }
    }
}
