package org.xbib.elasticsearch.common.util;

import java.io.DataInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public class FileServer extends Thread {
  
  private final static Logger logger = LogManager.getLogger("jdb.fileserver");
  private final static String WorkDir = System.getProperty("user.dir");
  private ServerSocket ss;
  
  public FileServer(int port) {
    try {
      String hostname = InetAddress.getLocalHost().getHostName();
      ss = new ServerSocket(port, 200, 
        InetAddress.getByName(hostname));
      logger.info("Working dir "+ WorkDir);
      logger.info("FileServer started on "+hostname+":"+port);
    } catch (IOException e) {
      logger.error("Error starting FileServer message="+e.getMessage(), e);
    }
  }
  
  public void run() {
    while (true) {
      try {
        Socket clientSock = ss.accept();
        logger.info("Accepting connection from " + 
        clientSock.getRemoteSocketAddress().toString());
        saveFile(clientSock);
      } catch (IOException e) {
        e.printStackTrace();
      }
    }
  }

  private void saveFile(Socket clientSock) throws IOException {
    DataInputStream dis = new DataInputStream(clientSock.getInputStream());
    byte[] buffer = new byte[4096];
    
    int filesize = dis.readInt();
    String fileName= dis.readUTF();
    logger.info("Recieving file with length=" + filesize);
    logger.info("Recieving file with name=" + fileName);
    FileOutputStream fos = new FileOutputStream(WorkDir+"/"+fileName);
    int read = 0;
    int remaining = filesize;
    while((read = dis.read(buffer, 0, Math.min(buffer.length, remaining))) > 0) {
      remaining -= read;
      fos.write(buffer, 0, read);
    }
    
    fos.close();
    dis.close();
  }
  
  public static void main(String[] args) {
    FileServer fs = new FileServer(1988);
    fs.start();
  }

}