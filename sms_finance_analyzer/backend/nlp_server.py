from flask import Flask, request, jsonify
import spacy
import re

app = Flask(__name__)
nlp = spacy.load("en_core_web_sm")

# Custom regex for amount and date
amount_regex = re.compile(r'(?:INR|Rs\.?|₹)\s?([0-9,]+(?:\.\d{1,2})?)')
date_regex = re.compile(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b')

def categorize(sms):
    sms_lower = sms.lower()
    if any(word in sms_lower for word in ['fuel', 'petrol', 'diesel']):
        return 'Fuel'
    elif any(word in sms_lower for word in ['grocery', 'supermarket']):
        return 'Groceries'
    elif any(word in sms_lower for word in ['credited', 'salary', 'deposit']):
        return 'Income'
    elif any(word in sms_lower for word in ['debited', 'purchase', 'spent']):
        return 'Expense'
    return 'Other'

@app.route('/analyze', methods=['POST'])
def analyze():
    sms = request.json.get('sms', '')
    doc = nlp(sms)
    entities = [(ent.text, ent.label_) for ent in doc.ents]

    # Extract amount and date using regex
    amount = amount_regex.search(sms)
    date = date_regex.search(sms)

    result = {
        'entities': entities,
        'amount': amount.group(1) if amount else None,
        'date': date.group(0) if date else None,
        'category': categorize(sms)
    }
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
