package org.xbib.elasticsearch.common.util;

import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public class FileClient implements Runnable {
  
  private final static Logger logger = LogManager.getLogger("jdbc.fileclient");  
  private Socket s;
  private String fileServer;
  private int fileServerPort;
  private String[] files;
  
  public FileClient(String fileServer, int port, String[] files) {
    this.fileServer = fileServer;
    this.fileServerPort = port;
    this.files = files;   
  }
  
  public void run() {
    try {
      s = new Socket(this.fileServer, this.fileServerPort);
      for(String file: this.files) {
        logger.info("Sending file="+file +" to "+this.fileServer+":"+this.fileServerPort);
        sendFile(file);    
      }
      logger.info("All files sucessfully send");
    } catch (Exception e) {
      logger.error("Error while sending file "+ e.getMessage(), e);
    }   
  }
  
  public void sendFile(String file) throws IOException {
    DataOutputStream dos = new DataOutputStream(s.getOutputStream());
    File myFile = new File (file);
    FileInputStream fis = new FileInputStream(file);
    byte[] buffer = new byte[(int)myFile.length()];
    dos.writeInt(buffer.length);
    dos.writeUTF(myFile.getName());
    
    while (fis.read(buffer) > 0) {
      dos.write(buffer);
    }
    
    fis.close();
    dos.close();  
  }
  
  public static void main(String[] args) throws UnknownHostException {
    
    ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    String[] filesToSend= {"/tmp/send/tickers.log", "/tmp/send/tickers_all"};
    FileClient fc = new FileClient(InetAddress.getLocalHost().getHostName(), 
      1988, filesToSend);
    scheduler.scheduleAtFixedRate(fc, 10, 10, TimeUnit.SECONDS);
    
  }

}
