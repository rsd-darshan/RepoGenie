#!/bin/bash

# Get the repository URL from the first argument
REPO_URL=$1
RETRIES=3
DELAY=5

# Function to display usage instructions
usage() {
  echo "Usage: $0 <repo_url>"
  exit 1
}

# Check if repository URL is provided
if [ -z "$REPO_URL" ]; then
  usage
fi

# Extract the repository name
REPO_NAME=$(basename "$REPO_URL" .git)

# Function to clone the repository with retry logic
clone_repo() {
  local attempt=0
  while (( attempt < RETRIES )); do
    echo "Cloning repository (attempt $((attempt + 1)) of $RETRIES)..."
    git clone "$REPO_URL"
    if [ $? -eq 0 ]; then
      cd "$REPO_NAME" || exit
      echo "Repository cloned successfully."
      return 0
    fi
    echo "Failed to clone repository. Retrying in $DELAY seconds..."
    sleep $DELAY
    ((attempt++))
  done
  echo "Failed to clone repository after $RETRIES attempts."
  exit 1
}

# Function to run a command and check if it succeeds
run_command() {
  "$@"
  if [ $? -ne 0 ]; then
    echo "Command failed: $*"
    return 1
  fi
  return 0
}

# Function to handle npm commands with fallbacks
handle_npm_project() {
  echo "Handling npm project..."

  # Ensure npm is installed
  if ! command -v npm &> /dev/null; then
    echo "npm is not installed. Please install npm and try again."
    exit 1
  fi

  # Install dependencies with npm
  run_command npm install || {
    echo "npm install failed. Trying yarn..."
    handle_yarn_project
    return
  }

  # Run npm audit fix
  run_command npm audit fix || {
    echo "npm audit fix failed. Trying npm audit fix --force..."
    run_command npm audit fix --force || echo "npm audit fix --force failed."
  }

  # Try various npm start scripts
  run_command npm start || run_command npm run start || run_command npm run dev || run_command npm run serve || {
    echo "All npm start scripts failed. Trying yarn..."
    handle_yarn_project
  }
}

# Function to handle yarn commands with fallbacks
handle_yarn_project() {
  echo "Handling yarn project..."

  # Ensure yarn is installed
  if ! command -v yarn &> /dev/null; then
    echo "yarn is not installed. Please install yarn and try again."
    exit 1
  fi

  # Install dependencies with yarn
  run_command yarn install || {
    echo "yarn install failed."
    exit 1
  }

  # Run yarn audit fix
  run_command yarn audit fix || {
    echo "yarn audit fix failed. Trying yarn audit fix --force..."
    run_command yarn audit fix --force || echo "yarn audit fix --force failed."
  }

  # Try various yarn start scripts
  run_command yarn start || run_command yarn run start || run_command yarn run dev || run_command yarn run serve || {
    echo "All yarn start scripts failed."
    exit 1
  }
}

# Function to handle Python projects
handle_python_project() {
  echo "Handling Python project..."
  if command -v pip &> /dev/null; then
    generate_requirements
    pip install -r requirements.txt
    if [ $? -ne 0 ]; then
      echo "Failed to install Python dependencies."
      exit 1
    fi
    if [ -f "manage.py" ]; then
      python manage.py runserver
      if [ $? -ne 0 ]; then
        echo "Failed to start Django server."
        exit 1
      fi
    elif [ -f "app.py" ]; then
      python app.py
      if [ $? -ne 0 ]; then
        echo "Failed to start Flask server."
        exit 1
      fi
    else
      echo "Python project type not recognized."
      exit 1
    fi
  else
    echo "pip is not installed."
    exit 1
  fi
}

# Function to handle Ruby projects
handle_ruby_project() {
  echo "Handling Ruby project..."
  if command -v bundle &> /dev/null; then
    bundle install
    if [ $? -ne 0 ]; then
      echo "Failed to install Ruby dependencies."
      exit 1
    fi
    rails server
    if [ $? -ne 0 ]; then
      echo "Failed to start Rails server."
      exit 1
    fi
  else
    echo "Bundler is not installed. Attempting to install..."
    if command -v gem &> /dev/null; then
      gem install bundler
      if [ $? -ne 0 ]; then
        echo "Failed to install Bundler."
        exit 1
      fi
      bundle install && rails server
      if [ $? -ne 0 ]; then
        echo "Failed to install Ruby dependencies or start Rails server."
        exit 1
      fi
    else
      echo "RubyGems is not installed. Cannot proceed."
      exit 1
    fi
  fi
}

# Function to handle Hugo projects
handle_hugo_project() {
  echo "Handling Hugo project..."
  if command -v hugo &> /dev/null; then
    hugo server --watch
    if [ $? -ne 0 ]; then
      echo "Failed to start Hugo server."
      exit 1
    fi
  else
    echo "Hugo is not installed."
    exit 1
  fi
}

# Function to handle PHP projects
handle_php_project() {
  echo "Handling PHP project..."
  if command -v php &> /dev/null; then
    if [ -f "wp-config.php" ]; then
      php -S localhost:8000
      if [ $? -ne 0 ]; then
        echo "Failed to start PHP server for WordPress."
        exit 1
      fi
    elif [ -f "app/etc/config.php" ]; then
      php bin/magento serve
      if [ $? -ne 0 ]; then
        echo "Failed to start PHP server for Magento."
        exit 1
      fi
    else
      echo "PHP project type not recognized."
      exit 1
    fi
  else
    echo "PHP is not installed."
    exit 1
  fi
}

# Function to handle Java projects
handle_java_project() {
  echo "Handling Java project..."
  if command -v mvn &> /dev/null; then
    mvn install
    if [ $? -ne 0 ]; then
      echo "Failed to install Maven dependencies."
      exit 1
    fi
    mvn exec:java
    if [ $? -ne 0 ]; then
      echo "Failed to start Java application using Maven."
      exit 1
    fi
  elif command -v gradle &> /dev/null; then
    gradle build
    if [ $? -ne 0 ]; then
      echo "Failed to build project using Gradle."
      exit 1
    fi
    gradle run
    if [ $? -ne 0 ]; then
      echo "Failed to start Java application using Gradle."
      exit 1
    fi
  else
    echo "Neither Maven nor Gradle is installed."
    exit 1
  fi
}

# Function to handle Go projects
handle_go_project() {
  echo "Handling Go project..."
  if command -v go &> /dev/null; then
    go build -o app
    if [ $? -ne 0 ]; then
      echo "Failed to build Go application."
      exit 1
    fi
    ./app
    if [ $? -ne 0 ]; then
      echo "Failed to start Go application."
      exit 1
    fi
  else
    echo "Go is not installed."
    exit 1
  fi
}

# Function to handle Docker projects
handle_docker_project() {
  echo "Handling Docker project..."
  if command -v docker &> /dev/null; then
    docker-compose up -d
    if [ $? -ne 0 ]; then
      echo "Failed to start Docker containers."
      exit 1
    fi
  else
    echo "Docker is not installed."
    exit 1
  fi
}

# Clone the repository and navigate to the project directory
clone_repo

# Create a directory to store the clone path
STORE_DIR="$HOME/clone_store"
mkdir -p "$STORE_DIR"

# Save the absolute path of the cloned repository to a file within the new directory
echo "$(pwd)" > "$STORE_DIR/clone_path.txt"

# Check for project types and perform actions accordingly with fallbacks
if [ -f "package.json" ]; then
  handle_npm_project
elif [ -f "Gemfile" ]; then
  handle_ruby_project
elif [ -f "requirements.txt" ]; then
  handle_python_project
elif [ -f "config.toml" ]; then
  handle_hugo_project
elif [ -f "wp-config.php" ] || [ -f "app/etc/config.php" ]; then
  handle_php_project
elif [ -f "pom.xml" ] || [ -f "build.gradle" ]; then
  handle_java_project
elif [ -f "main.go" ]; then
  handle_go_project
elif [ -f "docker-compose.yml" ]; then
  handle_docker_project
else
  echo "No recognized project setup found."
  exit 1
fi
