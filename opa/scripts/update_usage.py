#!/usr/bin/env python3
"""
OPAL Usage Tracker

This script consumes OPA decision logs and updates the usage data in OPAL.
It tracks rate limiting usage for the zero-trust architecture.
"""

import json
import time
import requests
import logging
import os
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('opal-usage-tracker')

# Configuration
OPAL_SERVER_URL = os.environ.get('OPAL_SERVER_URL', 'http://opal-server:7002')
OPAL_AUTH_TOKEN = os.environ.get('OPAL_AUTH_TOKEN', 'ZeroTrustDemo2023')

# Obter lista de URLs de logs de decisão (pode ser múltiplos OPAs)
OPA_DECISION_LOGS = os.environ.get('OPA_DECISION_LOGS', 'http://ext_authz-opa-service-1:8181/v1/decision_logs,http://ext_authz-opa-service-2:8181/v1/decision_logs')
# Limpa as aspas e espaços extras
OPA_DECISION_LOGS = OPA_DECISION_LOGS.replace('"', '').strip()
OPA_LOG_URLS = [url.strip() for url in OPA_DECISION_LOGS.split(',')]

logger.info(f"Configured OPA log URLs: {OPA_LOG_URLS}")

UPDATE_INTERVAL = int(os.environ.get('UPDATE_INTERVAL', '5'))  # seconds
TIME_WINDOW = int(os.environ.get('TIME_WINDOW', '60'))  # seconds

# In-memory cache of current usage data
usage_cache = {}

def obtain_token():
    """Obtain a data source token from OPAL server."""
    url = f"{OPAL_SERVER_URL}/token"
    headers = {"Authorization": f"Bearer {OPAL_AUTH_TOKEN}"}
    
    try:
        response = requests.post(
            url, 
            headers=headers,
            json={"type": "datasource"}
        )
        response.raise_for_status()
        return response.json().get("token")
    except Exception as e:
        logger.error(f"Failed to obtain token: {e}")
        return None

def clean_expired_entries():
    """Remove expired entries from the usage cache."""
    current_time = time.time()
    expired_time = current_time - TIME_WINDOW
    
    keys_to_remove = []
    for user_id, usage_data in usage_cache.items():
        # Filter out old timestamps
        new_entries = [(timestamp, cost) for timestamp, cost in usage_data["entries"] 
                     if timestamp > expired_time]
        
        if not new_entries:
            keys_to_remove.append(user_id)
        else:
            usage_cache[user_id]["entries"] = new_entries
            # Recalculate total cost
            usage_cache[user_id]["cost"] = sum(cost for _, cost in new_entries)
    
    # Remove empty entries
    for key in keys_to_remove:
        del usage_cache[key]

def update_usage_data(token):
    """Update usage data in OPAL based on current cache."""
    if not usage_cache:
        logger.info("No usage data to update")
        return
    
    clean_expired_entries()
    
    url = f"{OPAL_SERVER_URL}/data"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # Prepare the data update
    data = {
        "usage_tracker": usage_cache
    }
    
    try:
        response = requests.put(
            url,
            headers=headers,
            json={
                "path": "",
                "data": data,
                "policy_data": True
            }
        )
        response.raise_for_status()
        logger.info(f"Successfully updated usage data for {len(usage_cache)} users")
    except Exception as e:
        logger.error(f"Failed to update usage data: {e}")

def process_decision_log(decision):
    """Process a decision log entry and update the usage cache."""
    try:
        # Check if this is a valid decision with the data we need
        if not decision.get("result") or "response" not in decision["result"]:
            return
        
        response = decision["result"]["response"]
        
        # Skip if not tracking usage (like for admin or whitelisted endpoints)
        if "user_id" not in response or "cost_request" not in response:
            return
        
        user_id = response["user_id"]
        cost = response["cost_request"]
        user_key = f"{user_id}/usage"
        
        # Update cache
        current_time = time.time()
        if user_key not in usage_cache:
            usage_cache[user_key] = {
                "entries": [(current_time, cost)],
                "cost": cost
            }
        else:
            usage_cache[user_key]["entries"].append((current_time, cost))
            usage_cache[user_key]["cost"] += cost
            
        logger.debug(f"Updated usage for {user_id}: +{cost}")
    except Exception as e:
        logger.error(f"Error processing decision log: {e}")

def fetch_decision_logs():
    """Fetch decision logs from all OPA instances."""
    total_decisions = 0
    
    for url in OPA_LOG_URLS:
        try:
            logger.info(f"Fetching logs from {url}")
            response = requests.get(url)
            response.raise_for_status()
            decisions = response.json()
            
            for decision in decisions:
                process_decision_log(decision)
                
            logger.info(f"Processed {len(decisions)} decision logs from {url}")
            total_decisions += len(decisions)
        except Exception as e:
            logger.error(f"Failed to fetch decision logs from {url}: {e}")
    
    return total_decisions

def main():
    """Main execution function."""
    logger.info("Starting OPAL Usage Tracker")
    logger.info(f"Monitoring OPA instances: {OPA_LOG_URLS}")
    
    while True:
        try:
            # Get a token for data updates
            token = obtain_token()
            if not token:
                logger.warning("No token available, retrying in 10 seconds")
                time.sleep(10)
                continue
            
            # Fetch and process decision logs
            total_decisions = fetch_decision_logs()
            logger.info(f"Total decisions processed: {total_decisions}")
            
            # Update usage data in OPAL
            update_usage_data(token)
            
            # Wait for next update cycle
            time.sleep(UPDATE_INTERVAL)
        except KeyboardInterrupt:
            logger.info("Shutting down")
            break
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            time.sleep(UPDATE_INTERVAL)

if __name__ == "__main__":
    main() 