import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:path_provider/path_provider.dart';

class VideoUploadPage extends StatefulWidget {
  @override
  _VideoUploadPageState createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  final ImagePicker _picker = ImagePicker();
  final Trimmer _trimmer = Trimmer();
  
  File? _videoFile;
  double _startValue = 0.0;
  double _endValue = 0.0;
  
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  Future<void> _pickVideo() async {
    final XFile? pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );

    if (pickedFile != null) {
      _videoFile = File(pickedFile.path);
      await _trimmer.loadVideo(videoFile: _videoFile!);
      
      setState(() {
        _endValue = _trimmer.videoPlayerController!.value.duration.inMilliseconds.toDouble();
      });

      // Navigate to trimming page
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => TrimmerView(
          trimmer: _trimmer, 
          videoFile: _videoFile!,
          onTrimComplete: (trimmedVideo) {
            setState(() {
              _videoFile = trimmedVideo;
            });
          },
        )),
      );
    }
  }

  void _uploadVideo() {
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a video first')),
      );
      return;
    }

    // Validate video length
    if (_endValue - _startValue > 60000) {  // 60 seconds in milliseconds
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video must be 60 seconds or less')),
      );
      return;
    }

    // Here you would implement your actual video upload logic
    // This might involve calling an API, uploading to cloud storage, etc.
    print('Uploading video: ${_videoFile!.path}');
    print('Caption: ${_captionController.text}');
    print('Tags: ${_tagsController.text}');

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Video uploaded successfully!')),
    );

    // Clear the form
    setState(() {
      _videoFile = null;
      _captionController.clear();
      _tagsController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Reel'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video Selection
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green),
                ),
                child: _videoFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library, color: Colors.green, size: 50),
                          SizedBox(height: 10),
                          Text(
                            'Select Video (Max 60 sec)',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            _videoFile!,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              icon: Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _videoFile = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 16),

            // Caption Input
            TextField(
              controller: _captionController,
              decoration: InputDecoration(
                labelText: 'Write a caption',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.text_fields),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            SizedBox(height: 16),

            // Tags Input
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: 'Add Tags (separated by commas)',
                hintText: 'eg: farming, agriculture, tips',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            SizedBox(height: 16),

            // Upload Button
            ElevatedButton(
              onPressed: _uploadVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Upload Reel',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrimmerView extends StatefulWidget {
  final Trimmer trimmer;
  final File videoFile;
  final Function(File) onTrimComplete;

  const TrimmerView({
    Key? key, 
    required this.trimmer, 
    required this.videoFile,
    required this.onTrimComplete,
  }) : super(key: key);

  @override
  _TrimmerViewState createState() => _TrimmerViewState();
}

class _TrimmerViewState extends State<TrimmerView> {
  double _startValue = 0.0;
  double _endValue = 0.0;

  bool _isPlaying = false;
  bool _progressVisibility = false;

  Future<String?> _saveVideo() async {
    setState(() {
      _progressVisibility = true;
    });

    String? savedPath;
    await widget.trimmer.saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
      onSave: (String? outputPath) async {
        savedPath = outputPath;
        setState(() {
          _progressVisibility = false;
        });
      },
    );

    return savedPath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trim Video'),
        backgroundColor: Colors.green,
      ),
      body: Builder(
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.only(bottom: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Visibility(
                  visible: _progressVisibility,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.green,
                  ),
                ),
                
                // Video Trimmer
                VideoViewer(trimmer: widget.trimmer),
                
                Center(
                  child: TrimViewer(
                    trimmer: widget.trimmer,
                    viewerHeight: 50.0,
                    viewerWidth: MediaQuery.of(context).size.width,
                    maxVideoLength: const Duration(seconds: 60),
                    onChangeStart: (value) {
                      _startValue = value;
                    },
                    onChangeEnd: (value) {
                      _endValue = value;
                    },
                    onChangePlaybackState: (value) {
                      setState(() {
                        _isPlaying = value;
                      });
                    },
                  ),
                ),
                
                TextButton(
                  child: _isPlaying
                      ? Icon(
                          Icons.pause,
                          size: 30.0,
                          color: Colors.green,
                        )
                      : Icon(
                          Icons.play_arrow,
                          size: 30.0,
                          color: Colors.green,
                        ),
                  onPressed: () async {
                    bool playbackState =
                        await widget.trimmer.videoPlaybackControl(
                      startValue: _startValue,
                      endValue: _endValue,
                    );
                    setState(() {
                      _isPlaying = playbackState;
                    });
                  },
                ),
                
                ElevatedButton(
                  onPressed: () async {
                    String? savedPath = await _saveVideo();
                    if (savedPath != null) {
                      widget.onTrimComplete(File(savedPath));
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Save Trimmed Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}