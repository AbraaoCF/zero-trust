#!/usr/bin/env python3
"""
OPAL Usage Tracker

This script consumes OPA decision logs and updates the usage data in OPAL.
It tracks rate limiting usage for the zero-trust architecture.
Using webhook approach exclusively to receive decision logs directly from OPA.
"""

import json
import time
import requests
import logging
import os
import threading
import gzip
import io
from flask import Flask, request, jsonify

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('opal-usage-tracker')

# Configuration
OPAL_SERVER_URL = os.environ.get('OPAL_SERVER_URL', 'http://opal-server:7002')
OPAL_AUTH_TOKEN = os.environ.get('OPAL_AUTH_TOKEN', 'ZeroTrustDemo2025')

# Webhook server configuration 
WEBHOOK_PORT = int(os.environ.get('WEBHOOK_PORT', '8080'))
logger.info(f"Using webhook server on port {WEBHOOK_PORT}")

UPDATE_INTERVAL = int(os.environ.get('UPDATE_INTERVAL', '5'))  # seconds
TIME_WINDOW = int(os.environ.get('TIME_WINDOW', '60'))  # seconds

# In-memory cache of current usage data
usage_cache = {}

# Flask app for webhook server
app = Flask(__name__)

# Queue for storing incoming decision logs from the webhook
decision_queue = []
queue_lock = threading.Lock()

@app.route('/', methods=['GET'])
def health_check():
    """Simple health check endpoint for Docker healthcheck."""
    return jsonify({"status": "healthy", "service": "usage-tracker"}), 200


@app.route('/decisions/logs', methods=['POST'])
def receive_decision():
    """Endpoint to receive decision logs from OPA."""
    try:
        # Check Content-Encoding header for gzip
        content_encoding = request.headers.get('Content-Encoding', '')
        
        if 'gzip' in content_encoding.lower():
            # Decompress the gzipped data
            try:
                compressed_data = request.data
                with gzip.GzipFile(fileobj=io.BytesIO(compressed_data), mode='rb') as f:
                    json_data = f.read()
                content = json.loads(json_data)
                logger.info(f"Successfully decompressed gzipped data")
            except Exception as e:
                logger.error(f"Error decompressing gzipped data: {e}")
                return jsonify({"status": "error", "message": "Failed to decompress gzipped data"}), 400
        else:
            # Regular JSON data
            content = request.json
        
        # Debug log the content (only in development)
        debug_level = os.environ.get('LOG_LEVEL', 'info').lower()
        if debug_level == 'debug':
            logger.debug(f"Received content: {json.dumps(content, indent=2)}")
        
        if not content:
            return jsonify({"status": "error", "message": "No data received"}), 400
        
        # Add to queue for processing
        with queue_lock:
            if isinstance(content, list):
                # OPA can send multiple decisions in a single batch
                for decision in content:
                    decision_queue.append(decision)
                logger.info(f"Received {len(content)} decision logs from OPA")
            else:
                # Single decision
                decision_queue.append(content)
                logger.info("Received a single decision log from OPA")
        
        return jsonify({"status": "success"}), 200
    except Exception as e:
        logger.error(f"Error receiving decision log: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 400

def start_webhook_server():
    """Start the Flask webhook server in a separate thread."""
    threading.Thread(target=lambda: app.run(host='0.0.0.0', port=WEBHOOK_PORT, debug=False), daemon=True).start()
    logger.info(f"Webhook server started on port {WEBHOOK_PORT}")

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
    
    url = f"{OPAL_SERVER_URL}/data/config"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # Prepare the data update in the correct format expected by OPAL
    try:
        response = requests.post(
            url,
            headers=headers,
            json={
                "entries": [
                    {
                        "url": "",
                        "config": {},
                        "topics": ["policy_data"],
                        "dst_path": "/usage_tracker",
                        "save_method": "PUT",
                        "data": usage_cache
                    }
                ],
                "reason": "Update usage tracking data",
                "callback": {
                    "callbacks": []
                }
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
            logger.debug(f"Skipping decision log without result or response: {decision.get('decision_id', 'unknown')}")
            return
        
        response = decision["result"]["response"]
        
        # Skip if not tracking usage (like for admin or whitelisted endpoints)
        if "user_id" not in response or "cost_request" not in response:
            logger.debug(f"Skipping decision log without required fields: {decision.get('decision_id', 'unknown')}")
            return
        
        user_id = response["user_id"]
        cost = response["cost_request"]
        
        # Just use the user_id as the key
        if user_id not in usage_cache:
            usage_cache[user_id] = {
                "entries": [(time.time(), cost)],
                "cost": cost
            }
        else:
            usage_cache[user_id]["entries"].append((time.time(), cost))
            usage_cache[user_id]["cost"] += cost
            
        logger.info(f"Updated usage for {user_id}: +{cost}")
    except Exception as e:
        logger.error(f"Error processing decision log: {e}")

def process_webhook_queue():
    """Process the decision logs received via webhook."""
    with queue_lock:
        queue_copy = decision_queue.copy()
        decision_queue.clear()
    
    total_decisions = len(queue_copy)
    if total_decisions > 0:
        logger.info(f"Processing {total_decisions} decisions from webhook queue")
        for decision in queue_copy:
            process_decision_log(decision)
    
    return total_decisions

def main():
    """Main execution function."""
    logger.info("Starting OPAL Usage Tracker")
    
    # Start webhook server
    start_webhook_server()
    logger.info("Webhook server started, waiting for OPA to send decision logs")
    
    while True:
        try:
            # Get a token for data updates
            token = obtain_token()
            if not token:
                logger.warning("No token available, retrying in 10 seconds")
                time.sleep(10)
                continue
            
            # Process logs from webhook queue
            total_decisions = process_webhook_queue()
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