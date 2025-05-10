import xml.etree.ElementTree as ET
from datetime import datetime
import json
import openai

# ==== CONFIG ====
openai.api_key = "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"  # Replace with your actual OpenAI API key
XML_PATH = "sms_backup.xml"  # Your SMS backup XML file

# === Step 1: Parse SMS Messages ===
def parse_sms_xml(xml_file):
    tree = ET.parse(xml_file)
    root = tree.getroot()
    messages = []

    for sms in root.findall("sms"):
        body = sms.get("body", "")
        timestamp = int(sms.get("date"))
        date_str = datetime.fromtimestamp(timestamp / 1000.0).strftime('%Y-%m-%d %H:%M:%S')

        messages.append({
            "text": body.strip(),
            "date": date_str
        })

    return messages

# === Step 2: Ask GPT to Analyze ===
def ask_gpt_about_expenses(messages, question):
    short_messages = messages[:50]  # GPT has a context limit, trim to fit

    prompt = f"""
You are a financial assistant. The following are text messages (SMS) from a user's bank and card providers.

Analyze these messages and answer the question that follows.

Messages:
{json.dumps(short_messages, indent=2)}

Question: {question}
"""

    response = openai.ChatCompletion.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "user", "content": prompt}
        ],
        temperature=0.3
    )

    return response['choices'][0]['message']['content']

# === Step 3: Run the Script ===
if __name__ == "__main__":
    messages = parse_sms_xml(XML_PATH)

    print("\n✅ Loaded", len(messages), "SMS messages.")

    # Example question
    user_question = "what i smy current bank balance?"
    answer = ask_gpt_about_expenses(messages, user_question)

    print("\n🧠 GPT's Answer:\n")
    print(answer)
