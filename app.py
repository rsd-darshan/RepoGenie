from flask import Flask, request, render_template, jsonify
import os
import subprocess
import platform
import logging
import threading

app = Flask(__name__)

# Set up logging
logging.basicConfig(level=logging.DEBUG)

# Function to open a new terminal and run a command
def open_new_terminal_and_run(command):
    logging.debug(f"Executing command: {command}")
    if platform.system() == 'Windows':
        # Windows: use 'start' to open a new terminal window
        subprocess.Popen(['start', 'cmd', '/c', command], shell=True)
    elif platform.system() == 'Darwin':
        # macOS: use 'osascript' to open a new terminal window
        script = f'tell application "Terminal" to do script "{command}"'
        subprocess.Popen(['osascript', '-e', script])
    else:
        # Linux and other UNIX-like OSes: use 'xterm' or 'gnome-terminal'
        subprocess.Popen(['xterm', '-e', command])

# Route to handle the form submission and open a new terminal
@app.route('/clone', methods=['POST'])
def clone():
    repo_url = request.form['repo_url']
    script_path = os.path.abspath("process_repo.sh")
    command = f'bash {script_path} {repo_url}'
    
    logging.debug(f"Received repo URL: {repo_url}")
    logging.debug(f"Script path: {script_path}")

    try:
        threading.Thread(target=open_new_terminal_and_run, args=(command,)).start()
        return jsonify({"status": "success"})
    except Exception as e:
        logging.error(f"Error opening new terminal: {e}")
        return jsonify({"status": "error", "message": str(e)})

# Function to read the cloned repository path
def get_cloned_repo_path():
    try:
        clone_path_file = os.path.join(os.path.expanduser("~"), 'clone_store', 'clone_path.txt')
        with open(clone_path_file, 'r') as file:
            clone_path = file.read().strip()
            logging.debug(f"Cloned repository path: {clone_path}")
            return clone_path
    except Exception as e:
        logging.error(f"Error reading clone path: {e}")
        return None

# Function to create a script for word replacement
def create_replacement_script(repo_path, search_text, replace_text):
    script_content = f"""
#!/bin/bash
search_text="{search_text}"
replace_text="{replace_text}"
repo_path="{repo_path}"

# Escape special characters in search and replace texts for use in Perl
search_text=$(printf '%s\\n' "$search_text" | sed -e 's/[\\/&]/\\\\&/g')
replace_text=$(printf '%s\\n' "$replace_text" | sed -e 's/[\\/&]/\\\\&/g')

# Use Perl to replace text in all files in the repo_path
find "$repo_path" -type f -exec perl -pi -e "s/$search_text/$replace_text/g" {{}} +

echo "Words and sentences replaced successfully."
"""
    script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "replace_words.sh")
    with open(script_path, 'w') as script_file:
        script_file.write(script_content)
    os.chmod(script_path, 0o755)  # Make the script executable
    return script_path

# Route to replace words in the cloned repository
@app.route('/replace', methods=['POST'])
def replace_words():
    search_text = request.form['search_text']
    replace_text = request.form['replace_text']
    repo_path = get_cloned_repo_path()
    
    if repo_path is None:
        return jsonify({"status": "error", "message": "Cloned repository path not found."})
    
    logging.debug(f"Creating replacement script for '{search_text}' with '{replace_text}' in directory: {repo_path}")
    
    try:
        script_path = create_replacement_script(repo_path, search_text, replace_text)
        command = f'bash {script_path}'
        threading.Thread(target=open_new_terminal_and_run, args=(command,)).start()
        return jsonify({"status": "success", "message": "Replacement script started in a new terminal."})
    except Exception as e:
        logging.error(f"Error creating or running replacement script: {e}")
        return jsonify({"status": "error", "message": str(e)})

@app.route('/')
def index():
    return render_template('index.html')

if __name__ == '__main__':
    app.run(debug=True)
