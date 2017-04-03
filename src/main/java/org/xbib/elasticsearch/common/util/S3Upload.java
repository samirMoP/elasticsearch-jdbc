package org.xbib.elasticsearch.common.util;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.PutObjectRequest;

public class S3Upload implements Runnable {
  
  private final static Logger logger = LogManager.getLogger("jdb.s3upload");
  private final String bucket = "pg2esimporter";
  private List<File> files;
  private AmazonS3 s3Client;
  
  public S3Upload(List<File> files) {
    this.files = files;
    this.s3Client = AmazonS3ClientBuilder.defaultClient(); 
  }
  
  @Override
  public void run() {
    logger.info("No files to upload="+ files.size());
    for(File file: files) {
      while(!file.exists()) {
        logger.info("Wating for " + file.getName() + " to be crated");
        try {
          Thread.sleep(10000);
        } catch (InterruptedException e) {
          logger.error("InteruptException", e);
        }
      }     
      logger.info("Uploading file: "+ file.getName());
      s3Client.putObject(new PutObjectRequest(bucket, file.getName(), file));
      logger.info("Done");
    } 
  }  
  
  public static void main(String[] args) throws IOException {
    ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    List<File> filesToSend= new ArrayList<File>();
    filesToSend.add(new File("/tmp/send/tickers.log")); 
    S3Upload uploader = new S3Upload(filesToSend);
    scheduler.scheduleAtFixedRate(uploader, 10, 10, TimeUnit.SECONDS);
    

    }
}
