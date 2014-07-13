//
//  ViewController.m
//  Second Prototype
//
//  Created by Aliaa Essameldin on 6/1/14.
//  Copyright (c) 2014 Aliaa Essameldin. All rights reserved.
//

#import "ViewController.h"


// Declare C callback functions
void AQInputCallback(void * inUserData,  // Custom audio metadata
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs);

@implementation ViewController

#pragma mark - UIViewController

- (void)viewDidLoad
{
    //load background picture
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"bg.jpg"]];
    
    //setting up display text field
    recognizedText.editable = NO;
    recognizedText.text = @"No recognized Text Yet";
    
    //setting up main button
    UIImage *btnImage = [UIImage imageNamed:@"start.png"];
    [dictationButton setBackgroundImage:btnImage forState:UIControlStateNormal];
    
    //initiating flags
    dictating = NO;
    
    //initializing Audio session
    NSError *audioSessionError;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&audioSessionError];
    if(audioSessionError)
    {
        NSLog(@"AVAudioSession error setting category:%@",audioSessionError);
    }
    else
    {
        [audioSession setActive:YES error:&audioSessionError];
        if(audioSessionError)
            NSLog(@"AVAudioSession error activating: %@",audioSessionError);
    }
    
    //load view
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBActions

-(IBAction)clearText:(id)sender
{
    recognizedText.text = @"No recognized Text Yet";
}

-(IBAction)startDictation:(id)sender
{
    if (dictating)      //the button should act as a pause button
    {
        [self stop];
        UIImage *btnImage = [UIImage imageNamed:@"start.png"];
        [dictationButton setBackgroundImage:btnImage forState:UIControlStateNormal];
        
    } else              //the button should act as a record button
    {
        [self start];
        UIImage *btnImage = [UIImage imageNamed:@"stop.png"];
        [dictationButton setBackgroundImage:btnImage forState:UIControlStateNormal];
    }
    
}

#pragma mark - Controlling Dictator

-(void)start
{
    
    dictating = YES;                    //adjust flag
    [self initNetworkCommunication];    //establish a TCP connection with the server
    [self AQmain];                      //start a new AudioQueue
    
    recorder.running = YES;             //adjust UserData's flag
    AudioQueueStart(queue, NULL);
    
}

-(void)stop
{
    dictating = NO;                     //adjust flag
    [outputStream close];               //tear up previous TCP streams
    [inputStream close];
    recorder.running = NO;              //adjust UserData's flag
    AudioQueueStop(queue, YES);
}

#pragma mark - AudioQueue

-(void) AQmain
{
    //setting up the audio's format
    AudioStreamBasicDescription recordFormat;
    memset(&recordFormat, 0, sizeof(recordFormat));
    
    recordFormat.mFormatID = kAudioFormatLinearPCM;
    recordFormat.mChannelsPerFrame = 1;
    recordFormat.mSampleRate = 16000;
    recordFormat.mChannelsPerFrame = 1;
    recordFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger;
    
    recordFormat.mFormatFlags        = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    recordFormat.mFramesPerPacket    = 1;
    recordFormat.mBitsPerChannel     = 16;
    recordFormat.mBytesPerPacket     = 2;
    recordFormat.mBytesPerFrame      = 2;
    
    
    //setting up queue
    AudioQueueNewInput(&recordFormat,
                       AQInputCallback,
                       &recorder,
                       CFRunLoopGetCurrent(),
                       kCFRunLoopCommonModes,
                       0,
                       &queue);
    
    
    //creating buffers in the queue
    int bufferByteSize = 1024;
    int bufferIndex;
    for (bufferIndex = 0; bufferIndex < NUM_BUFFERS; ++bufferIndex)
    {
        AudioQueueBufferRef buffer;
        
        AudioQueueAllocateBuffer(queue,
                                 bufferByteSize,
                                 &buffer);
        
        AudioQueueEnqueueBuffer(queue,
                                buffer,
                                0,
                                NULL);
    }
    
    //Saving View Controller's variables in the recorder struct
    recorder.stream = (__bridge void *)(outputStream);
    recorder.queue = queue;
}

//buffer callback function - called whenever a buffer is full
void AQInputCallback(void * inUserData,
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs)
{
    //extract the data in the inUserData struct
    recorderx *recorder = (recorderx*)inUserData;
    NSOutputStream *outputstream = (__bridge NSOutputStream*)recorder->stream;
    
    //creating the packet to be sent
    //data
    NSData *data_body = [[NSData alloc] initWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
    
    //data size
    int i = [data_body length];
    if (i%2 != 0) //size must be even (server expectation)
    {
        i--;
    }
    NSData *size = [NSData dataWithBytes: &i length: sizeof(i)];
    
    //appending to one object
    NSMutableData *packet = [[NSMutableData alloc] init];
    [packet appendData:size];
    [packet appendData:data_body];
    
    if (i>0)    //only send buffers with data
    {
        [outputstream write:[packet bytes] maxLength:[packet length]];
    }
    
    //return the buffer to the end of the queue
    AudioQueueEnqueueBuffer(recorder->queue, inBuffer, 0, NULL);
}

#pragma mark - SocketConnection
- (void)initNetworkCommunication
{
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    
    
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)CFBridgingRetain([NSString stringWithFormat:@"%s", IP_ADDRESS]), PORT_NUMBER, &readStream, &writeStream);
    
    //FIX THE INSANE MACRO HERE
    inputStream = (__bridge NSInputStream *)readStream;
    outputStream = (__bridge NSOutputStream *)writeStream;
    
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [inputStream open];
    [outputStream open];
    
    //stream = (__bridge void *)(outputStream);
    recorder.stream = (__bridge void *)(outputStream);
}

//handling stream events
- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
	switch (streamEvent) {
            
		case NSStreamEventOpenCompleted:
			NSLog(@"Stream opened");
			break;
            
        case NSStreamEventHasSpaceAvailable:
            break;
            
		case NSStreamEventHasBytesAvailable:
			if (theStream == inputStream) {
                
                uint8_t buffer[1024];
                int len;
                
                while ([inputStream hasBytesAvailable]) {
                    len = [inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0) {
                        
                        NSString *input = [[NSString alloc] initWithBytes:buffer length:len encoding:NSUTF8StringEncoding];
                        
                        if (nil != input) {
                            NSLog(@"server said: %@", input);
                            [self displayText:input];
                        }
                    }
                }
            }
            
            
            break;
            
		case NSStreamEventErrorOccurred:
        {
			NSLog(@"Can not connect to the host!");
            
            UIAlertView *wifiLostAlert = [[UIAlertView alloc] initWithTitle:@"Wifi connection error" message:@"" delegate:nil cancelButtonTitle:@"Continue" otherButtonTitles:nil];
            
            [wifiLostAlert show];
            
			break;
        }

		case NSStreamEventEndEncountered:
            break;
            
		default:
			NSLog(@"Unknown event");
	}
    
}

-(void)displayText:(NSString *)reply
{
    //start text recognition string
    if ([recognizedText.text isEqualToString: @"No recognized Text Yet"])
    {
        recognizedText.text = @"";
    }
    
    //parsing input
    NSArray *lines = [[NSArray alloc] initWithArray:[reply componentsSeparatedByString:@"\n"]];
    NSString *input = @"";
    
    for (int i = 0; i<([lines count] - 2); i++)
    {
        NSArray *parser = [[NSArray alloc] initWithArray:[lines[i] componentsSeparatedByString:@" "]];
        input = [NSString stringWithFormat:@"%@ %@", input, parser[1]];
    }
    
    //displaying new text
    recognizedText.text = [NSString stringWithFormat:@"%@ %@", recognizedText.text, input];
}

@end
