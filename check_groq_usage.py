"""
Script to check Groq API usage and rate limits.
This helps you monitor your remaining free tier requests.
"""
import os
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

GROQ_API_KEY = os.environ.get("GROQ_API_KEY")
GROQ_API_URL = os.environ.get(
    "GROQ_API_URL",
    "https://api.groq.com/openai/v1/chat/completions",
)
GROQ_MODEL = os.environ.get("GROQ_MODEL", "llama3-8b-8192")

def check_groq_status():
    """Check Groq API status and rate limits."""
    if not GROQ_API_KEY:
        print("[ERROR] GROQ_API_KEY is not set in your .env file")
        print("\nTo set it up:")
        print("1. Get your API key from: https://console.groq.com/keys")
        print("2. Add to your .env file: GROQ_API_KEY=your-api-key-here")
        return
    
    print("[CHECK] Checking Groq API status...")
    print(f"[MODEL] Model: {GROQ_MODEL}")
    print(f"[URL] API URL: {GROQ_API_URL}\n")
    
    # Make a test request to check rate limits
    try:
        payload = {
            "model": GROQ_MODEL,
            "messages": [
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": "Say 'OK' if you can read this."}
            ],
            "max_tokens": 10,
            "temperature": 0.1,
        }
        headers = {
            "Authorization": f"Bearer {GROQ_API_KEY}",
            "Content-Type": "application/json",
        }
        
        resp = requests.post(GROQ_API_URL, json=payload, headers=headers, timeout=15)
        
        # Check response headers for rate limit info
        print("[RATE LIMITS] Rate Limit Headers:")
        rate_limit_headers = {
            'x-ratelimit-limit-requests': 'Rate Limit (requests)',
            'x-ratelimit-remaining-requests': 'Remaining Requests',
            'x-ratelimit-reset-requests': 'Reset Time (requests)',
            'x-ratelimit-limit-tokens': 'Rate Limit (tokens)',
            'x-ratelimit-remaining-tokens': 'Remaining Tokens',
            'x-ratelimit-reset-tokens': 'Reset Time (tokens)',
        }
        
        found_headers = False
        for header, description in rate_limit_headers.items():
            value = resp.headers.get(header)
            if value:
                found_headers = True
                print(f"  {description}: {value}")
        
        if not found_headers:
            print("  [WARNING] No rate limit headers found in response")
        
        print(f"\n[STATUS] Response Status: {resp.status_code}")
        
        if resp.status_code == 200:
            print("[SUCCESS] API is working correctly!")
            data = resp.json()
            if 'choices' in data and len(data['choices']) > 0:
                content = data['choices'][0].get('message', {}).get('content', '')
                print(f"[SUCCESS] Test response: {content}")
            
            # Check for usage info in response
            if 'usage' in data:
                usage = data['usage']
                print(f"\n[USAGE] Token Usage (this request):")
                print(f"  Prompt tokens: {usage.get('prompt_tokens', 'N/A')}")
                print(f"  Completion tokens: {usage.get('completion_tokens', 'N/A')}")
                print(f"  Total tokens: {usage.get('total_tokens', 'N/A')}")
        
        elif resp.status_code == 429:
            print("[WARNING] Rate limit exceeded! You've hit the free tier limit.")
            print("   Wait for the reset time or upgrade to Developer Tier.")
            print(f"   Response: {resp.text}")
        
        elif resp.status_code == 401:
            print("[ERROR] Invalid API key. Please check your GROQ_API_KEY in .env")
            print(f"   Response: {resp.text}")
        
        else:
            print(f"[WARNING] Unexpected status code: {resp.status_code}")
            print(f"   Response: {resp.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"[ERROR] Error connecting to Groq API: {e}")
    except Exception as e:
        print(f"[ERROR] Unexpected error: {e}")

def print_groq_info():
    """Print information about Groq's free tier."""
    print("\n" + "="*60)
    print("GROQ AI FREE TIER INFORMATION")
    print("="*60)
    print("""
[YES] Groq offers a FREE tier with:
   - Access to core models (like llama3-8b-8192)
   - Generous rate limits for development/testing
   - No credit card required to start

[LIMITS] Free Tier Limits (approximate):
   - ~30 requests per minute (RPM)
   - ~14,400 requests per day (RPD)
   - Token limits vary by model

[PAID] Developer Tier (Pay-as-you-go):
   - 10x higher rate limits
   - Access to Batch API
   - More models available
   - Pricing: ~$0.11-$0.60 per million tokens (varies by model)

[LINKS]
   - Get your API key: https://console.groq.com/keys
   - Documentation: https://console.groq.com/docs
   - Pricing details: https://groq.com/pricing

[TIPS]
   - Monitor rate limit headers in API responses
   - Use smaller max_tokens to reduce usage
   - Cache responses when possible
   - Upgrade to Developer Tier if you need more capacity
    """)
    print("="*60 + "\n")

if __name__ == "__main__":
    print_groq_info()
    check_groq_status()

