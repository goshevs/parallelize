from boxsdk import OAuth2, Client


auth = OAuth2(
    client_id='<>',
    client_secret='<>',
    access_token='<>',
)

client = Client(auth)

# step 1
# confirm access
user = client.user().get()
print('The current user is {0}'.format(user.name))


# step 2
# next is find either folder_id or file_id (or both)

# using search funtion in sdk
myDir = client.search().query(
    'workWithJay',
    type=['folder'],
    content_type='names',
    offset=0,
    limit=10,
)

myFile = client.search().query(
    'test',
    type=['file'],
    file_extensions=['txt'],
    offset=0,
    limit=10,
)

for d, r in zip(myDir, myFile):
    print("\n", d.name, '<<: names :>>', r.name)
    folderId = d.id
    fileId = r.id
    print(folderId, "<<: id's :>>", fileId)


# step 3
# using file_id, I can use sdk to download it
box_file = client.file(file_id=fileId).get()
output_file = open(box_file.name, 'wb')
box_file.download_to(output_file)


# step 4
# next I will upload a file back using folder_id
uploaded_file = client.folder(folderId).upload('test.txt')
