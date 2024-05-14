import os
import json
from datetime import datetime
from math import ceil
from googleapiclient.discovery import build
import pandas as pd

def chunks(l, n):
    for i in range(0, len(l), n):
        yield l[i:i+n]

api_key = os.getenv("YOUTUBE_DATA_API_V3_KEY")
# example channel: Ethio 360 Media
channel_id = "UCvr6jA3WYOhXFUD2LKpqhQw"

youtube = build("youtube", "v3", developerKey=api_key)

# get channel info ----
## refer https://developers.google.com/youtube/v3/getting-started#fields
response_channel = youtube.channels().list(
    part="snippet,statistics", id=channel_id, fields="items(snippet(title), statistics)"
    ).execute()
response_channel = response_channel["items"][0]
channel_title = response_channel["snippet"]["title"]


# get all the uploaded videos of the channel ----
video_count = int(response_channel["statistics"]["videoCount"])
maxResults = 50 # the max number of items that should be returned per page
num_pages = ceil(video_count / 50)

# refer https://developers.google.com/youtube/v3/guides/implementation/videos
playlist = youtube.channels().list(
    part="contentDetails", id=channel_id,
    fields="items/contentDetails/relatedPlaylists/uploads"
    ).execute()

playlist_id = playlist["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]

## iterate page by page and extract all the video ids ----
video_list = {}
nextPageToken = None

for page in range(1, num_pages + 1):
    playlist_items = youtube.playlistItems().list(
            part="contentDetails, snippet",
            playlistId=playlist_id,
            fields="nextPageToken, items(contentDetails(videoId, videoPublishedAt), snippet.position)",
            maxResults=maxResults,
            pageToken=nextPageToken
        ).execute()

    for item in playlist_items["items"]:
        video_list[item["contentDetails"]["videoId"]] = {**item['contentDetails'], **item['snippet']}

    nextPageToken = playlist_items.get("nextPageToken")
    if nextPageToken is None:
        break
    if page > 20 and page % 20 == 0:
        print(f"Page {page} out of num_pages {num_pages} searched.")


## get video content details, statistics, and other info ----
vid_ids = list(video_list.keys())
# the api handles only 50 videos at a time
# let's create chunks of video ids
vid_ids_chunks = list(chunks(vid_ids, 50))
# video ids in a chunk are concatnated together
vid_ids_chunks_joined = list(map(lambda chunk: ",".join(chunk), vid_ids_chunks))

# iterate over each chunk, and get the video contents
video_data = []
for chunk in vid_ids_chunks_joined:
    video_data.append(
        youtube.videos().list(
        part="snippet, contentDetails, statistics, liveStreamingDetails",
        id=chunk,
        fields="items(%s)" %(
        ", ".join(
            [
            "snippet(title, description, thumbnails.standard.url, tags)",
            "contentDetails(duration, definition, caption)",
            "statistics(viewCount, likeCount, commentCount)",
            "liveStreamingDetails()"
            ]
            ))
        ).execute()["items"]
        )

for i, chunk_data in enumerate(video_data):
    video_data[i] = dict(zip(vid_ids_chunks[i], chunk_data))
    # flatten the dicts, and make the video ids as keys
    video_data[i] = dict(
        zip(video_data[i].keys(), pd.json_normalize(video_data[i].values()).to_dict(orient="records"))
        )

# append the video data to video list (contains other info such as published date)
for chunk_data in video_data:
    for vid_id in chunk_data:
        video_list[vid_id].update(chunk_data[vid_id])

# write to disk ----
access_time = datetime.utcnow().strftime("%F %T %Z") # data access time
channel_dir = channel_title.replace(" ","-")
try:
    os.mkdir(channel_dir)
except FileExistsError:
    pass
suffix = f"{channel_dir}_{access_time}"

with open(f"{channel_dir}/channel-info_{suffix}.json", "w") as f:
    json.dump(response_channel, f, indent=4)
with open(f"{channel_dir}/channel-data_{suffix}.json", "w") as f:
    json.dump(video_list, f, indent=4)

# prefer a rectangular format (data frame) and write to csv
video_list_df = pd.DataFrame(video_list.values())
video_list_df.to_csv(f'{channel_dir}/channel-data_{suffix}.csv', index=False)


youtube.close()
