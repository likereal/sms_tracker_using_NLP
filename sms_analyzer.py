import xml.etree.ElementTree as ET
import re
from datetime import datetime

# === CONFIG ===
XML_FILE = "sms-2025.xml"

# Keywords to detect financial SMS
FINANCIAL_KEYWORDS = ["debited", "credited", "transaction", "purchase", "withdrawn", "paid"]

# Regex to extract money values
AMOUNT_REGEX = re.compile(r'(INR|Rs\.?|₹)\s?([\d,]+\.\d{2})', re.IGNORECASE)

def parse_sms(xml_file):
    tree = ET.parse(xml_file)
    root = tree.getroot()
    financial_sms = []

    for sms in root.findall("sms"):
        body = sms.get("body", "").lower()
        if any(keyword in body for keyword in FINANCIAL_KEYWORDS):
            date_ms = int(sms.get("date"))
            date = datetime.fromtimestamp(date_ms / 1000.0).strftime('%Y-%m-%d %H:%M:%S')
            financial_sms.append({
                "text": sms.get("body"),
                "date": date
            })
    return financial_sms

def extract_expenses(sms_list):
    total_expense = 0.0
    expense_messages = []

    for sms in sms_list:
        body = sms["text"]
        if "debited" in body.lower() or "withdrawn" in body.lower() or "purchase" in body.lower() or "paid" in body.lower():
            match = AMOUNT_REGEX.search(body)
            if match:
                amount = float(match.group(2).replace(",", ""))
                total_expense += amount
                expense_messages.append({**sms, "amount": amount})
    
    return total_expense, expense_messages

# === RUN SCRIPT ===
if __name__ == "__main__":
    print("Parsing SMS XML...")
    sms_data = parse_sms(XML_FILE)
    total_expense, expenses = extract_expenses(sms_data)

    print(f"\n📊 Total Expenses: ₹{total_expense:.2f}\n")
    print("🧾 Expense-related Messages:\n")
    for msg in expenses:
        print(f"[{msg['date']}] ₹{msg['amount']:.2f} — {msg['text'][:100]}...\n")
