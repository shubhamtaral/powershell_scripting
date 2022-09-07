import requests

url = "https://contractpod.greythr.com/uas/v1/oauth2/client-token"

payload={}
headers = {}

response = requests.request("POST", url, headers=headers, data=payload)

print(response.text)