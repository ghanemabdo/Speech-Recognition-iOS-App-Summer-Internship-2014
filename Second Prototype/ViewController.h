//
//  ViewController.h
//  Second Prototype
//
//  Created by Aliaa Essameldin on 6/1/14.
//  Copyright (c) 2014 Aliaa Essameldin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define NUM_BUFFERS 5

#define IP_ADDRESS  "localhost" // QCRI: "94.125.228.197"
#define PORT_NUMBER 12345

typedef struct MyRecorder {
    AudioQueueRef   queue;
    void            *stream;
    SInt64          recordPacket;
    BOOL            running;
} recorderx;


@interface ViewController : UIViewController <NSStreamDelegate>

{
    //Outlets
    IBOutlet UIButton *dictationButton;
    IBOutlet UITextView *recognizedText;
    
    //Global Flags
    BOOL dictating;
    
    //Global Variables from recorder
    recorderx       recorder;
    AudioQueueRef   queue;
    
    NSInputStream   *inputStream;
    NSOutputStream  *outputStream;
    void            *stream; 
    
}


//Actions
-(IBAction)clearText:(id)sender;
-(IBAction)startDictation:(id)sender;

@end
