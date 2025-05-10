import xml.etree.ElementTree as ET
import pandas as pd
import streamlit as st
import re
import os
from datetime import datetime

# === CONFIG ===
XML_FILE = "sms_backup.xml"

# Keywords to detect financial SMS
FINANCIAL_KEYWORDS = ["debited", "credited", "transaction", "purchase", "withdrawn", "paid"]

# Regex to extract money values
AMOUNT_REGEX = re.compile(r'(INR|Rs\.?|₹)\s?([\d,]+\.\d{2})', re.IGNORECASE)

# Regex to extract balance (e.g., "Avl Bal 4.00")
BALANCE_REGEX = re.compile(r'Avl Bal (\d+\.\d{2})\b', re.IGNORECASE)

# Define categories with keywords for NLP-based categorization
categories = {
    'Food': ['grocery', 'supermarket', 'restaurant', 'cafe'],
    'Housing': ['rent', 'mortgage', 'utilities'],
    'Transportation': ['gas', 'bus', 'train', 'taxi', 'avenue zipcash', 'phonepe recharge'],
    'Entertainment': ['movie', 'concert', 'game'],
    'Bills': ['olamoney', 'postpaid', 'recharge'],
    'Other': []
}

# Function to categorize transactions using NLP (keyword-based)
def categorize(description):
    desc_lower = description.lower()
    for category, keywords in categories.items():
        if any(keyword in desc_lower for keyword in keywords):
            return category
    return 'Other'

# Function to parse SMS and extract financial data
def parse_sms(xml_file):
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
    except ET.ParseError as e:
        st.error(f"Failed to parse XML file: {e}")
        raise
    except FileNotFoundError:
        st.error(f"XML file '{xml_file}' not found in {os.getcwd()}")
        raise

    financial_sms = []
    latest_balance = 0.0

    for sms in root.findall("sms"):
        body = sms.get("body", "").lower()
        address = sms.get("address", "")
        date = sms.get("date", "")

        # Filter financial messages
        if any(keyword in body for keyword in FINANCIAL_KEYWORDS) or 'BOIIND' in address:
            try:
                date_ms = int(date) / 1000  # Convert milliseconds to seconds
                date_str = datetime.utcfromtimestamp(date_ms).strftime('%Y-%m-%d %H:%M:%S')
            except ValueError:
                date_str = 'Unknown'

            # Extract amount
            amount_match = AMOUNT_REGEX.search(sms.get("body", ""))
            amount = float(amount_match.group(2).replace(",", "")) if amount_match else 0.0

            # Determine transaction type and balance
            transaction_type = 'other'
            balance = None
            description = sms.get("body", "")[:100]  # Default description

            if 'credited' in body:
                transaction_type = 'credit'
                description = body.split('by ')[-1].split('.')[0] if 'by ' in body else description
            elif any(keyword in body for keyword in ['debited', 'withdrawn', 'purchase', 'paid']):
                transaction_type = 'debit'
                amount = -amount  # Debits are negative
                description = body.split('from ')[-1].split('.')[0] if 'from ' in body else description

            # Extract balance from BOIIND messages
            balance_match = BALANCE_REGEX.search(sms.get("body", ""))
            if balance_match:
                try:
                    balance = float(balance_match.group(1))
                    latest_balance = max(latest_balance, balance)
                except ValueError as e:
                    st.warning(f"Failed to parse balance in SMS: {sms.get('body')[:100]}... - Error: {e}")
                    balance = None

            if amount != 0.0 or balance is not None:
                financial_sms.append({
                    "text": sms.get("body"),
                    "date": date_str,
                    "amount": amount,
                    "type": transaction_type,
                    "balance": balance,
                    "description": description,
                    "category": categorize(description)
                })

    return financial_sms, latest_balance

# Function to analyze expenses
def analyze_expenses(sms_list):
    total_expense = 0.0
    total_credits = 0.0
    expense_messages = []
    credit_messages = []

    for sms in sms_list:
        amount = sms["amount"]
        if sms["type"] == 'debit':
            total_expense += abs(amount)
            expense_messages.append(sms)
        elif sms["type"] == 'credit':
            total_credits += amount
            credit_messages.append(sms)

    return total_expense, total_credits, expense_messages, credit_messages

# === RUN SCRIPT ===
st.title('Financial Analysis Dashboard')

# Parse SMS
st.write("**Parsing SMS XML...**")
sms_data, latest_balance = parse_sms(XML_FILE)

# Debug: Display parsed transactions
st.write("**Debug: Parsed Financial Transactions**")
st.write(sms_data)

# Create DataFrame for transactions
if not sms_data:
    st.warning("No financial transactions found in XML")
    df_transactions = pd.DataFrame(columns=['date', 'description', 'amount', 'category', 'balance', 'type'])
else:
    df_transactions = pd.DataFrame(sms_data)
    df_transactions['date'] = pd.to_datetime(df_transactions['date'], errors='coerce')
    df_transactions['month'] = df_transactions['date'].dt.to_period('M')
    df_transactions['year'] = df_transactions['date'].dt.year
    df_transactions['month_name'] = df_transactions['date'].dt.strftime('%B')

# Sidebar Filters
st.sidebar.header("Filters")
# Year filter
years = ['All Years'] + sorted(df_transactions['year'].dropna().unique().astype(int).tolist())
selected_year = st.sidebar.selectbox("Select Year", years, index=0)

# Month filter
months = ['All Months'] + sorted(df_transactions['month_name'].dropna().unique().tolist())
selected_month = st.sidebar.selectbox("Select Month", months, index=0)

# Category filter
categories_list = ['All Categories'] + sorted(df_transactions['category'].unique().tolist())
selected_categories = st.sidebar.multiselect("Select Expenditure Type", categories_list, default=['All Categories'])

# Apply Filters
filtered_df = df_transactions.copy()
if selected_year != 'All Years':
    filtered_df = filtered_df[filtered_df['year'] == selected_year]
if selected_month != 'All Months':
    filtered_df = filtered_df[filtered_df['month_name'] == selected_month]
if 'All Categories' not in selected_categories:
    filtered_df = filtered_df[filtered_df['category'].isin(selected_categories)]

# Display filtered transaction count
st.write(f"**Filtered Transactions**: {len(filtered_df)}")

# Analyze filtered data
if filtered_df.empty:
    st.warning("No transactions match the selected filters")
    total_expense = 0.0
    total_credits = 0.0
    current_balance = 0.0
    initial_balance = 0.0
    expenditure_by_category = pd.Series()
    expenditure_by_month = pd.Series()
    top_spending_category = 'None'
    top_spending_amount = 0.0
    average_monthly_spending = 0.0
    largest_transaction = None
else:
    total_expense, total_credits, expenses, credits = analyze_expenses(filtered_df.to_dict('records'))
    current_balance = filtered_df[filtered_df['balance'].notnull()]['balance'].max() if filtered_df['balance'].notnull().any() else 0.0
    initial_balance = current_balance - (total_credits - total_expense)
    expenditure_by_category = filtered_df[filtered_df['type'] == 'debit'].groupby('category')['amount'].sum() * -1
    expenditure_by_month = filtered_df[filtered_df['type'] == 'debit'].groupby('month')['amount'].sum() * -1
    top_spending_category = expenditure_by_category.idxmax() if not expenditure_by_category.empty else 'None'
    top_spending_amount = expenditure_by_category.max() if not expenditure_by_category.empty else 0.0
    average_monthly_spending = expenditure_by_month.mean() if not expenditure_by_month.empty else 0.0
    largest_transaction = filtered_df[filtered_df['type'] == 'debit'].loc[
        filtered_df[filtered_df['type'] == 'debit']['amount'].idxmin()
    ] if not filtered_df[filtered_df['type'] == 'debit'].empty else None

# Prepare metadata for AI bot
summary = {
    'current_balance': current_balance,
    'initial_balance': initial_balance,
    'total_credits': total_credits,
    'total_debits': total_expense,
    'expenditure_by_category': expenditure_by_category.to_dict(),
    'top_spending_category': top_spending_category,
    'average_monthly_spending': average_monthly_spending,
    'largest_transaction': largest_transaction.to_dict() if largest_transaction is not None else {}
}

# Store metadata in DataFrames
df_balance = pd.DataFrame({
    'metric': ['Initial Balance', 'Total Credits', 'Total Debits', 'Current Balance'],
    'amount': [initial_balance, total_credits, total_expense, current_balance]
})

# Streamlit UI
st.header('Account Balance Analysis')
st.write(f"**Current Balance**: ₹{current_balance:.2f}")
st.write(f"**Initial Balance** (before transactions): ₹{initial_balance:.2f}")
st.write(f"**Total Credits**: ₹{total_credits:.2f}")
st.write(f"**Total Debits**: ₹{total_expense:.2f}")
st.dataframe(df_balance.style.format(formatter={'amount': '₹{:.2f}'}))

st.header('Expenditure Patterns')
st.write(f"**Total Expenditure**: ₹{total_expense:.2f}")
st.write(f"**Average Monthly Spending**: ₹{average_monthly_spending:.2f}")
st.write(f"**Top Spending Category**: {top_spending_category} (₹{top_spending_amount:.2f})")
if largest_transaction is not None:
    st.write(f"**Largest Transaction**: {largest_transaction['description']} on {largest_transaction['date']} (₹{-largest_transaction['amount']:.2f})")

st.subheader('Spending by Category')
if not expenditure_by_category.empty:
    st.bar_chart(expenditure_by_category)
else:
    st.write("No spending data available.")

st.subheader('Monthly Spending Trend')
if not expenditure_by_month.empty:
    st.line_chart(expenditure_by_month)
else:
    st.write("No monthly spending data available.")

st.header('Transaction Details')
st.dataframe(filtered_df)

st.header('Metadata for AI Bot')
st.json(summary)

if __name__ == "__main__":
    print("Run this script with: streamlit run sms_analyzer3.py")