/*
  convertIPs.c - Convert PeerGuardian lists to IP lists and IP ranges.
  Copyright (C) 2024, Ignacio Llorente https://ignacio.vercel.app
  Licensed under the GNU-GPLv2+
*/

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define MAX_LINE_LENGTH 250

typedef struct {
  uint8_t octet[4];
} IP; // Our IP format

// Parse the string into an IP format
IP parseIP(const char *ipStr) {
  IP ip;
  int result = sscanf(ipStr, "%hhu.%hhu.%hhu.%hhu", &ip.octet[0], &ip.octet[1],
                      &ip.octet[2], &ip.octet[3]);
  if (result != 4) {
    fprintf(stderr, "Error: Could not read all four octets correctly\n");
  }
  return ip;
}

// Calculate the mask from the two IPs
int prefixLength(IP startIP, IP endIP) {
  uint32_t start = (startIP.octet[0] << 24) | (startIP.octet[1] << 16) |
                   (startIP.octet[2] << 8) | startIP.octet[3];
  uint32_t end = (endIP.octet[0] << 24) | (endIP.octet[1] << 16) |
                 (endIP.octet[2] << 8) | endIP.octet[3];
  uint32_t xor = start ^ end;
  int length = 32;
  while (xor) {
    xor >>= 1;
    length--;
  }
  return length;
}

int main(int argc, char *argv[]) {
  // How to execute the program
  if (argc != 2) {
    fprintf(stderr, "Usage: %s <file_path>\n", argv[0]);
    return 1;
  }
  // The file path to be processed is passed as a parameter
  char *file_path = argv[1];

  // Open the file to process
  FILE *file = fopen(file_path, "r");
  if (file == NULL) {
    fprintf(stderr, "Error: Cannot open file %s\n", file_path);
    return 1;
  }

  // Open in "append" mode the file where the results will be dumped
  FILE *outputFile = fopen("ranges/listsOfNETs.txt", "a");
  if (outputFile == NULL) {
    fprintf(stderr, "Error: Cannot open or create the output file\n");
    fclose(file);
    return 1;
  }

  // Iterate line by line
  char line[MAX_LINE_LENGTH];
  while (fgets(line, sizeof(line), file)) {

    // We check if the line exceeds the maximum length
    if (strlen(line) >= MAX_LINE_LENGTH - 1) {
      fprintf(stderr, "Error: The line exceeds the maximum allowed length\n");
      continue;
    }

    // Discard comments and empty lines
    if (line[0] == '#' || line[0] == '\n')
      continue;

    // Get the first and second IP addresses in string format
    char *startStr = strchr(line, ':');
    if (startStr == NULL)
      continue;

    startStr += 1; // Move to the next position after the colon
    char *endStr = strchr(startStr, '-');
    if (endStr == NULL)
      continue;

    *endStr = '\0'; // End the string at the hyphen

    // Transform those IPs from string into our IP format
    IP startIP = parseIP(startStr);
    IP endIP = parseIP(endStr + 1);

    // Calculate the mask
    int mask = prefixLength(startIP, endIP);

    // Write to the output file startIP/mask
    fprintf(outputFile, "%d.%d.%d.%d/%d\n", startIP.octet[0], startIP.octet[1],
            startIP.octet[2], startIP.octet[3], mask);
  }
  if (fclose(file) == EOF) {
    fprintf(stderr, "Error: Failed to close input file\n");
    return 1;
  }
  if (fclose(outputFile) == EOF) {
    fprintf(stderr, "Error: Failed to close output file\n");
    return 1;
  }
  return 0;
}