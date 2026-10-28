using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(DoorManager))]
public class KeycardDoor : MonoBehaviour
{
    public static List<KeycardDoor> doors = new List<KeycardDoor>();

    private DoorManager door;
    [Header("Main")]
    [SerializeField] private KeycardLevel level;
    [SerializeField] private GameObject[] keySlots;
    [SerializeField] private Transform hitBox;
    [SerializeField] private GameObject roomArea;

    [Header("Settings")]
    [SerializeField] private bool startOpen = false;
    [SerializeField] private AnimationCurve CurveAnim;

    private bool canInteract;

    [Header("Audio")]
    [SerializeField] private DoorSFX sfxObj;

    [Header("Access")]
    public bool doorOpen;
    public bool isBangingOnDoor = false;

    private int angersLeft = 1;

    private void Awake()
    {
        doors.Add(this);
        door = GetComponent<DoorManager>();
        SetupLights();
    }
    private void OnDestroy()
    {
        doors.Remove(this);
    }
    void Start()
    {
        canInteract = true;

        door.SetDoor(startOpen);
        doorOpen = startOpen;
    }
    void Update()
    {
        checkSlots();
    }

    public void ForceDoorOpen()
    {
        StartCoroutine(ToggleDoor(true));
    }

    public void ForceDoorClosed()
    {
        StartCoroutine(ToggleDoor(false));
    }

    private void SetupLights()
    {
        foreach (GameObject slot in keySlots)
        {
            Transform successLight = slot.transform.Find("SuccessLight");
            if (successLight != null)
            {
                successLight.GetComponent<Renderer>().material = new Material(successLight.GetComponent<Renderer>().material);
                Material mat = successLight.GetComponent<Renderer>().material;
                mat.SetColor("_EmissionColor", Color.black * 0);
            }
        }
    }

    public static KeycardDoor GetDoorWithinRange(Vector3 pos, float range)
    {
        for (int i = doors.Count - 1; i >= 0; i--)
        {
            if (doors[i] == null)
            {
                doors.RemoveAt(i);
                continue;
            }

            if ((pos - doors[i].transform.position).sqrMagnitude <= range * range)
            {
                return doors[i];
            }
        }
        return null;
    }

    private IEnumerator ToggleDoor(bool open, GameObject slot = null, GameObject cardHole = null, GameObject card = null)
    {
        if (!canInteract) yield break;
        canInteract = false;

        if (cardHole != null)
        {
            bool correctCard = card.GetComponent<Keycard>().level >= level;
            StartCoroutine(ValidateCard(slot, correctCard));
            StartCoroutine(CardAnim(cardHole, card));
            yield return new WaitForSeconds(1f);
            if (!correctCard)
            {
                yield return new WaitForSeconds(1f);
                canInteract = true;
                yield break;
            }

        }

        AudioClip sfx = open ? sfxObj.doorOpen : sfxObj.doorClose;
        SFXManager.instance.PlaySFXClip(sfx, hitBox, 1f, false);

        door.SetDoor(open);
        doorOpen = open;

        yield return new WaitForSeconds(2.2f);
        canInteract = true;
    }

    private IEnumerator CardAnim(GameObject cardHole, GameObject card)
    {
        Vector3 startPos = cardHole.transform.position + cardHole.transform.right * 0.4f;
        Vector3 endPos = cardHole.transform.position + cardHole.transform.right * 0.1f; ;

        GameObject newKey = Instantiate(card);
        newKey.transform.SetParent(cardHole.transform);
        Inventory.SetLayerRecursive(newKey.transform, LayerMask.NameToLayer("Default"));

        newKey.transform.localRotation = Quaternion.Euler(0, 0, 0);
        newKey.transform.localScale = new Vector3(0.4f, 0.6f, 0.7f);

        float timer = 0f;
        while (timer < 1)
        {
            float t = CurveAnim.Evaluate(timer);
            newKey.transform.position = Vector3.Slerp(startPos, endPos, t);
            timer += Time.deltaTime / 0.6f;
            yield return null;
        }

        yield return new WaitForSeconds(0.75f);
        Destroy(newKey);
    }

    private IEnumerator ValidateCard(GameObject slot, bool success)
    {
        yield return new WaitForSeconds(0.3f);

        Transform successLight = slot.transform.Find("SuccessLight");
        if (successLight == null) yield break;

        AudioClip sfx = success ? sfxObj.success : sfxObj.fail;
        SFXManager.instance.PlaySFXClip(sfx, successLight, 0.5f, true);

        yield return new WaitForSeconds(0.3f);

        successLight.GetComponent<Renderer>().material = new Material(successLight.GetComponent<Renderer>().material);
        Material mat = successLight.GetComponent<Renderer>().material;

        mat.SetColor("_EmissionColor", Color.black * 0);

        Color lightCol = success ? new Color(1.401937f, 23.96863f, 4.345418f) : new Color(24.75472f, 3.892111f, 3.316198f);
        StartCoroutine(LerpEmission(mat, 0, 5, 0.3f, lightCol, true));

        
    }

    private void checkSlots()
    {
        foreach (GameObject slot in keySlots)
        {
            checkIfInteracted(slot);
            foreach (Transform childTransform in slot.transform)
            {
                GameObject childGameObject = childTransform.gameObject;
                checkIfInteracted(childGameObject);
            }
        }
    }

    private void checkIfInteracted(GameObject slot)
    {
        Camera cam = Inventory.instance.cam;
        Ray ray = new Ray(cam.transform.position, cam.transform.forward);
        if (Physics.Raycast(ray, out RaycastHit hit, 2.5f))
        {
            GameObject heldItem = Inventory.instance.getHeldItem();
            if (hit.transform.gameObject == slot &&
            heldItem != null &&
            heldItem.GetComponent<Keycard>() &&
            !isBangingOnDoor &&
            Input.GetKeyDown(KeyCode.E))
            {
                GameObject hole = null;

                if (slot.name == "Hole")
                {
                    hole = slot;
                }
                else if (slot.transform.Find("Hole") != null)
                {
                    hole = slot.transform.Find("Hole").gameObject;
                }
                else if (slot.transform.parent.Find("Hole") != null)
                {
                    hole = slot.transform.parent.Find("Hole").gameObject;
                }

                StartCoroutine(ToggleDoor(!doorOpen, hole.transform.parent.gameObject, hole, heldItem));
            }
        }
    }

    private IEnumerator LerpEmission(Material mat, float startIntensity, float endIntensity, float duration, Color emissionColor, bool firstWay = false)
    {
        float timer = 0f;

        mat.EnableKeyword("_EMISSION");

        while (timer < duration)
        {
            float t = timer / duration;

            float intensity = Mathf.Lerp(startIntensity, endIntensity, t);
            Color finalColor = emissionColor * intensity;

            mat.SetColor("_EmissionColor", finalColor);

            timer += Time.deltaTime;
            yield return null;
        }

        mat.SetColor("_EmissionColor", emissionColor * endIntensity);

        if (firstWay) StartCoroutine(LerpEmission(mat, endIntensity, startIntensity, duration, emissionColor));
    }

    public void BangOnDoor(Action action, bool angry = false)
    {
        if (isBangingOnDoor) return;
        isBangingOnDoor = true;

        IEnumerator doSFX(Action action)
        {
            int times = (angry) ? 3 : 1;
            for (int i = 0; i < times; i++)
            {
                SFXManager.instance.PlaySFXClip(sfxObj.hit, transform, 0.75f, true);
                yield return new WaitForSeconds(0.75f);
                if (i == 2 && angersLeft > 0)
                {
                    
                }
            }
            if (angry && angersLeft == 0)
            {
                ForceDoorOpen();
                Monster.instance.Anger();
                yield break;
            }
            isBangingOnDoor = false;
            yield return new WaitForSeconds(3f);
            action?.Invoke();

            if (angry) angersLeft = 0;
        }

        StartCoroutine(doSFX(action));
    }

    public bool PosIsInRoom(Vector3 pos)
    {
        return roomArea.GetComponent<Collider>().bounds.Contains(pos);
    }

    public bool PlayerIsInRoom()
    {
        return roomArea.GetComponent<Collider>().bounds.Contains(Player.instance.transform.position);
    }

    public static Vector3 GetPlayerRoomPos(Vector3 monstPos)
    {
        foreach (KeycardDoor door in doors)
        {
            if (door.PlayerIsInRoom() && !door.doorOpen && !door.PosIsInRoom(monstPos))
            {
                return door.transform.position + door.transform.forward * -2f;
            }
        }
        return Vector3.zero;
    }
}
