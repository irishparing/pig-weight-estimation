// Import necessary libraries
import kinect4WinSDK.*;
import com.hamoid.*;
import fi.iki.elonen.NanoHTTPD;

import java.io.*;
import java.util.Map;
import java.util.HashMap;

import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;

import java.nio.file.Files;
import java.nio.file.Paths;

import javax.swing.JOptionPane; // For the input prompt
import java.io.FileWriter; // For writing to the CSV file

Kinect kinect;
VideoExport depthRgbVideoExport;
boolean isRecording = false;
int recordFileIndex = 1;
String lastFileName = ""; // To store the last recording's filename
String csvFileName = "C:\\Users\\USER\\Documents\\Processing\\Kinect_Code\\recordings_data.csv";

void setup() {
  size(1280, 480); // Adjusted for side-by-side depth and RGB images
  frameRate(30);
  kinect = new Kinect(this);
  loadRecordFileIndex();
  updateVideoExportPaths();

  // Start NanoHTTPD server
  try {
    MyHTTPServer server = new MyHTTPServer(8080);
    server.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false);
    println("Server running at http://localhost:8080");
  } catch (IOException e) {
    e.printStackTrace();
  }
}

void draw() {
  background(0);

  PImage depthImage = kinect.GetDepth();
  PImage rgbImage = kinect.GetImage();

  if (depthImage != null && rgbImage != null) {
    depthImage = createHeatmap(depthImage); // Convert depth image to heatmap
    image(depthImage, 0, 0); // Draw heatmap depth image on the left
    image(rgbImage, depthImage.width, 0); // Draw RGB image on the right

    if (isRecording) {
      depthRgbVideoExport.saveFrame();
    }
  } else {
    println("Images are null.");
  }
}

PImage createHeatmap(PImage depthImage) {
  depthImage.loadPixels();
  PImage heatmap = createImage(depthImage.width, depthImage.height, RGB);
  heatmap.loadPixels();

  for (int i = 0; i < depthImage.pixels.length; i++) {
    float depthValue = red(depthImage.pixels[i]); // Extract depth intensity from red channel
    float normalizedValue = map(depthValue, 0, 255, 0, 1); // Normalize between 0 and 1
    heatmap.pixels[i] = getHeatmapColor(normalizedValue); // Map to heatmap color
  }

  heatmap.updatePixels();
  return heatmap;
}

int getHeatmapColor(float value) {
  float r = constrain(lerp(0, 255, value * 2 - 1), 0, 255);
  float g = constrain(lerp(255, 0, abs(value * 2 - 1)), 0, 255);
  float b = constrain(lerp(255, 0, value * 2), 0, 255);
  return color(r, g, b);
}

void loadRecordFileIndex() {
  try {
    if (Files.exists(Paths.get(csvFileName))) {
      long lineCount = Files.lines(Paths.get(csvFileName)).count();
      recordFileIndex = (int) lineCount + 1; // Set index based on line count
    }
  } catch (IOException e) {
    e.printStackTrace();
  }
}

void updateVideoExportPaths() {
  lastFileName = "depth_rgb_recording(" + recordFileIndex + ").mp4"; // Store the filename
  depthRgbVideoExport = new VideoExport(this, lastFileName);
}

// Recording functions
void startRecording() {
  println("Recording started.");
  if (depthRgbVideoExport != null) {
    isRecording = true;
    depthRgbVideoExport.startMovie();
  } else {
    println("Error: VideoExport is null.");
  }
}

void stopRecording() {
  println("Recording stopped.");
  if (depthRgbVideoExport != null) {
    isRecording = false;
    depthRgbVideoExport.endMovie();
    lastFileName = "depth_rgb_recording(" + recordFileIndex + ").mp4"; // Update with the correct file name
    recordFileIndex++;
    updateVideoExportPaths();
  } else {
    println("Error: VideoExport is null.");
  }
}

// Append filename and weight to CSV file
void appendToCSV(String fileName, double weight) {
  try {
    FileWriter writer = new FileWriter(csvFileName, true);
    writer.append(fileName).append(",").append(String.valueOf(weight)).append("\n");
    writer.close();
    println("Data appended to " + csvFileName);
  } catch (IOException e) {
    e.printStackTrace();
    println("Error writing to CSV file: " + e.getMessage());
  }
}

void savePImageAsPNG(PImage img, ByteArrayOutputStream outputStream) {
  try {
    BufferedImage bufferedImage = (BufferedImage) img.getNative();
    ImageIO.write(bufferedImage, "png", outputStream);
  } catch (IOException e) {
    e.printStackTrace();
  }
}


// NanoHTTPD Server Class
class MyHTTPServer extends NanoHTTPD {
  public MyHTTPServer(int port) {
    super(port);
  }

  @Override
  public Response serve(IHTTPSession session) {
    String uri = session.getUri();
    String method = session.getMethod().toString();
    println("Received request at:", uri);

    if ("OPTIONS".equalsIgnoreCase(method)) {
      Response preflightResponse = newFixedLengthResponse(Response.Status.OK, "text/plain", "OK");
      addCorsHeaders(preflightResponse);
      return preflightResponse;
    }

    Response response;

    try {
      switch (uri) {
        case "/start":
          if (!isRecording) {
            startRecording();
          }
          response = newFixedLengthResponse(Response.Status.OK, "text/plain", "Recording started.");
          break;

        case "/stop":
          if (isRecording) {
            stopRecording();
          }
          response = newFixedLengthResponse(Response.Status.OK, "text/plain", "Recording stopped.");
          break;

        case "/save":
          if (session.getMethod() == Method.POST) {
            Map<String, String> postData = new HashMap<String, String>(); // FIXED SYNTAX
            session.parseBody(postData);

            String json = postData.get("postData");
            if (json == null || json.isEmpty()) {
              response = newFixedLengthResponse(Response.Status.BAD_REQUEST, "text/plain", "Invalid JSON.");
              break;
            }

            JSONObject data = parseJSONObject(json);
            double weight = data.getDouble("weight");

            if (lastFileName != null && !lastFileName.isEmpty()) {
              appendToCSV(lastFileName, weight);
              response = newFixedLengthResponse(Response.Status.OK, "text/plain", "Weight saved.");
            } else {
              response = newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "No recording file available.");
            }
          } else {
            response = newFixedLengthResponse(Response.Status.BAD_REQUEST, "text/plain", "Invalid request.");
          }
          break;

        case "/camera":
          Map<String, String> queryParams = session.getParms();
          boolean isDepth = "true".equals(queryParams.get("depth"));
          boolean isRgb = "true".equals(queryParams.get("rgb"));

          PImage image = null;
          if (isDepth) {
            image = kinect.GetDepth();
            image = createHeatmap(image);
          } else if (isRgb) {
            image = kinect.GetImage();
          }

          if (image != null) {
            image.resize(320, 240);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            savePImageAsPNG(image, baos);
            InputStream imageStream = new ByteArrayInputStream(baos.toByteArray());
            response = newChunkedResponse(Response.Status.OK, "image/png", imageStream);
          } else {
            response = newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "No camera feed available.");
          }
          break;

        default:
          response = newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Endpoint not found.");
      }
    } catch (Exception e) {
      e.printStackTrace();
      response = newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "An error occurred.");
    }

    addCorsHeaders(response);
    return response;
  }

  private void addCorsHeaders(Response response) {
    response.addHeader("Access-Control-Allow-Origin", "*");
    response.addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    response.addHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
  }
}
