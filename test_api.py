import requests

def search_animelok():
    url = 'https://api.tatakai.me/api/v1/animelok/search'
    params = {'q': 'Jujutsu Kaisen'}
    response = requests.get(url, params=params)
    print(response.json())

search_animelok()
