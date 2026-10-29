using System;
using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class PointSystem : MonoBehaviour
{
    public static PointSystem instance;

    private enum TypeOfEarn
    {
        Bounce = 1,
        Win = 200,
    }

    public int points = 0;
    public int betCount = 50;
    public float earnedPoints = 0;

    private string selectedBet = null;
    private bool alreadyBet = false;
    private Sprite selectedSprite = null;

    [Header("Setting Values")]
    private float betButtonTimer = 0f;
    public float buttonHoldTime = 0.5f;

    [Header("Bet Values")]
    public int minBet = 50;
    public int maxBet = 2000;

    [Header("UI")]
    public TextMeshProUGUI pointCnt;
    public TextMeshProUGUI earnCnt;
    public TextMeshProUGUI bettedPeng;
    public Image betPengImg;

    public TextMeshProUGUI betTxt;
    public TextMeshProUGUI warnTxt;

    public GameObject container;
    public GameObject penguinListing;
    public GameObject submitButton;
    public Button[] bettingButtons;

    [Header("Listing")]
    public GameObject bettingMenu;
    public TextMeshProUGUI pengName;
    public TextMeshProUGUI pengDescription;
    public Image pengImage;

    private void Awake()
    {
        if (instance == null) instance = this;
        bettingMenu.SetActive(false);
    }

    private void Start()
    {
        submitButton.GetComponent<Button>().onClick.AddListener(SelectBet);

        foreach (Button button in bettingButtons)
        {
            button.onClick.AddListener(() => AddBet(button));
        }
    }

    private void Update()
    {
        pointCnt.text = "Peng-bucks: " + points;
        earnCnt.text = $"{earnedPoints} ({earnedPoints - betCount})";

        bettedPeng.text = selectedBet;
        betPengImg.sprite = selectedSprite;

        betTxt.text = "Bet: $" + betCount;
        warnTxt.text = $"Min: {minBet}, Max: {maxBet}";

        UpdBetButton();
    }

    private void AddBet(Button button)
    {
        int amount;
        if (int.TryParse(button.name, out amount))
        {
            betCount = Mathf.Clamp(betCount + amount, minBet, maxBet);
        }
        else
        {
            Debug.LogWarning("Button name is not a number: " + button.name);
        }
    }

    private void UpdBetButton()
    {
        bool anyHeld = false;

        foreach (var button in bettingButtons)
        {
            if (!button.GetComponent<HoldBetButton>().holding) continue;

            anyHeld = true;
            betButtonTimer += Time.deltaTime;

            if (betButtonTimer >= buttonHoldTime)
            {
                AddBet(button);
                betButtonTimer = buttonHoldTime - 0.1f;
            }
        }

        if (!anyHeld)
            betButtonTimer = 0f;
    }

    public void ResetList()
    {
        selectedBet = null;
        alreadyBet = false;
        selectedSprite = null;

        pengName.enabled = false;
        pengDescription.enabled = false;
        pengImage.enabled = false;
        submitButton.SetActive(false);

        foreach (Transform child in container.transform)
        {
            Destroy(child.gameObject);
        }

        container.transform.localPosition = Vector3.zero;
        earnedPoints = 0;
    }

    public void LoadBet(string name, Sprite sprite)
    {
        GameObject newListing = Instantiate(penguinListing);
        GameObject img = newListing.transform.Find("Img").gameObject;
        newListing.name = name;
        newListing.transform.SetParent(container.transform, false);
        img.GetComponent<Image>().sprite = sprite;

        img.GetComponent<Button>().onClick.AddListener(() => Selected(name, sprite));
    }

    public void StartBets(Action act)
    {
        StartCoroutine(BettingStage(act));
    }

    public void CollectEarnings(string name)
    {
        if (name == selectedBet)
        {
            AddPengPoints(TypeOfEarn.Win);
        }
        points += (int)earnedPoints;
        SaveManager.Save();
    }

    private IEnumerator BettingStage(Action act)
    {
        bettingMenu.gameObject.SetActive(true);
        while (!alreadyBet)
        {
            yield return null;
        }

        act?.Invoke();

        points -= betCount;

        GameObject selectedPenguin = GameManager.instance.GetPengObjByName(selectedBet);
        if (selectedPenguin != null)
        {
            selectedPenguin.GetComponent<PenguinScript>().onBounce.AddListener(() => AddPengPoints(TypeOfEarn.Bounce));
        }
    }

    private void AddPengPoints(TypeOfEarn earn)
    {
        if (earn == TypeOfEarn.Bounce && !GameManager.instance.gameRunning) return;

        earnedPoints += (betCount * (float)earn * 0.01f);
    }

    private void Selected(string name, Sprite sprite)
    {
        Penguin peng = GameManager.instance.getPengByName(name);

        pengName.text = name;
        pengDescription.text = peng.desc;
        pengImage.sprite = sprite;

        pengName.enabled = true;
        pengDescription.enabled = true;
        pengImage.enabled = true;
        submitButton.SetActive(true);

        selectedSprite = sprite;
        selectedBet = name;
    }

    private void SelectBet()
    {
        if (alreadyBet) return;
        alreadyBet = true;
        bettingMenu.gameObject.SetActive(false);
    }
}
