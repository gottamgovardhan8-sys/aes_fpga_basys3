import serial
import time

# --- SETUP YOUR COM PORT HERE ---
# Change 'COM3' to whatever your Device Manager says (e.g., 'COM5', 'COM7')
SERIAL_PORT = 'COM3'  
BAUD_RATE = 115200

try:
    # Open the connection to the FPGA
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=2)
    print(f"Successfully connected to {SERIAL_PORT}")
    
    # 16-byte Key + 16-byte Plaintext (Official NIST Test Vector)
    key       = bytes.fromhex("2b7e151628aed2a6abf7158809cf4f3c")
    plaintext = bytes.fromhex("6bc1bee22e409f96e93d7e117393172a")

    print("Sending 32 bytes (Key + Plaintext) to FPGA...")
    ser.write(key + plaintext)

    # Wait a fraction of a second for the physical hardware to encrypt
    time.sleep(0.2)

    print("Reading 16 bytes of Ciphertext back from FPGA...")
    ciphertext = ser.read(16)

    # Display results
    print("\n--- AES ENCRYPTION RESULTS ---")
    print(f"Key Sent:        {key.hex()}")
    print(f"Plaintext Sent:  {plaintext.hex()}")
    print(f"FPGA Ciphertext: {ciphertext.hex()}")

    # Verify against the mathematical standard
    if ciphertext.hex() == "3ad77bb40d7a3660a89ecaf32466ef97":
        print("\n✅ SUCCESS! Hardware output perfectly matches the NIST Standard!")
    else:
        print("\n❌ ERROR: Incorrect data received or timed out.")
        
    ser.close()

except Exception as e:
    print(f"\nConnection Error: {e}")
    print(f"Make sure your Basys 3 is turned ON and you changed SERIAL_PORT to the correct port.")