一个轻量级的流媒体播放器，支持iPod音乐，网络音乐和本地音乐的播放，流媒体支持播放缓存

使用方法：
首先引入同文件 #import "LBAudioPlayer.h"

1、本地音乐

_audioPlayer = [[LBAudioPlayer alloc] initWithFilePath:filePath];

2、网络音乐
_audioPlayer = [[LBAudioPlayer alloc] initWithURL:url audioCachePath:[self papaCachePath:url]];

3、iPod音乐
NSURL *songUrl = [item valueForProperty:MPMediaItemPropertyAssetURL];
URL为获取的
_audioPlayer = [[LBAudioPlayer alloc] initWithAVURL:url];

详细可见demo


