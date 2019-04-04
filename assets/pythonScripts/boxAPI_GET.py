##############################################################################
# BOX API FILE DOWNLOAD
#
# v.0.1
#
# To run this file, in the terminal submit the following commands
# export FLASK_APP=boxAPI.py
# export FLASK_ENV=development
# flask run
#
#
# Need to have flask installed. To install run
# pip<3.?> install flask
#
#


from flask import Flask, redirect, request
from boxsdk import Client
from boxsdk import OAuth2
from threading import Timer

import config_oauth
import webbrowser


app = Flask(__name__)


# Create new OAuth client & csrf token
oauth = OAuth2(
    client_id=config_oauth.client_id,
    client_secret=config_oauth.client_secret
)
csrf_token = ''

# Create Box redirect URI with csrf token and redirect user
@app.route('/')
def start():
    global csrf_token
    auth_url, csrf_token = oauth.get_authorization_url(
        config_oauth.redirect_uri
    )

    return redirect(auth_url)


# Fetch access token and make authenticated request
@app.route('/return')
def capture():
    # Capture auth code and csrf token via state
    code = request.args.get('code')
    state = request.args.get('state')

    # If csrf token matches, fetch tokens
    assert state == csrf_token
    access_token, refresh_token = oauth.authenticate(code)

    # Check user info
    client = Client(oauth)
    user = client.user().get()
    print('The current user ID is {}'.format(user.id))

    # Get file info
    # myDir = client.search().query(
    #     'workWithJay',
    #     type=['folder'],
    #     content_type='names',
    #     limit=10, offset=0)

    myFile = client.search().query(
        'test',
        file_extensions=['txt'],
        type=['file'],
        content_type='names',
        limit=10,
        offset=0
    )

    # for d in myDir:
    #     print(d)

    for f in myFile:
        print("Name: ", f.name, " -- ID: ", f.id)
        if f.name == "test.txt":
            box_file = client.file(file_id=f.id).get()
            output_file = open(box_file.name, 'wb')
            box_file.download_to(output_file)

    return 'Done'


def open_browser():
    webbrowser.open(config_oauth.base_uri, new=0)


if __name__ == "__main__":
    Timer(1, open_browser).start()
    app.run()
