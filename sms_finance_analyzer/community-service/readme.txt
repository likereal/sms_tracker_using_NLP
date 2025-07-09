steps

1. Install Go (if not already installed): https://golang.org/dl/
2. Open a terminal and navigate to this directory.
3. Initialize the module (only needed once):
   go mod init community-service
4. Download dependencies:
   go mod tidy
5. Run the service (make sure to use a dot to include all files):
   go run .
   or 
   go run main.go

The server will start on port 1323 by default.
or 

