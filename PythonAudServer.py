# Echo server program
import socket
import wave
import time

CHUNK = 256
CHANNELS = 1
RATE = 16000
WAVE_OUTPUT_FILENAME = "receivedAudio.wav"
frames = []


HOST = ''                 # local host
PORT = 12345
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind((HOST, PORT))

wf = wave.open(WAVE_OUTPUT_FILENAME, mode='wb')
wf.setnchannels(CHANNELS)
wf.setsampwidth(2)
wf.setframerate(RATE)
print("listening on port 1200")

s.listen(1)
conn, addr = s.accept()
print ('Connected by', addr)
data = conn.recv(CHUNK)
i=1
while True: #MOSHKELA HENA
    if not data: break
    i=i+1
    data = conn.recv(CHUNK)
    if data != '':
        frames.append(data)

wf.writeframes(b''.join(frames))
#wf.writeframes(frames)
wf.close()

conn.close()
s.close()
