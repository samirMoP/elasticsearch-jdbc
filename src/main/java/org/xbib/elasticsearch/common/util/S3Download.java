package org.xbib.elasticsearch.common.util;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.GetObjectRequest;
import com.amazonaws.services.s3.model.ObjectListing;
import com.amazonaws.services.s3.model.S3Object;
import com.amazonaws.services.s3.model.S3ObjectSummary;

public class S3Download implements Runnable {
  
  private final static Logger logger = LogManager.getLogger("jdb.s3download");
  private final String bucket = "pg2esimporter";
  private File[] files;
  private AmazonS3 s3Client;
  
  public S3Download() {
    this.s3Client = AmazonS3ClientBuilder.defaultClient(); 
  }
  
  public void saveFile(S3Object obj) throws IOException {
    InputStream reader = new BufferedInputStream(
      obj.getObjectContent());
   File file = new File(obj.getKey());      
   OutputStream writer = new BufferedOutputStream(new FileOutputStream(file));
   int read = -1;

   while ( ( read = reader.read() ) != -1 ) {
       writer.write(read);
   }
   writer.flush();
   writer.close();
   reader.close();
  }
  
  @Override
  public void run() {
    ObjectListing listing = s3Client.listObjects(bucket);
    List<S3ObjectSummary> summaries = listing.getObjectSummaries();
    for(S3ObjectSummary object:summaries) {
      S3Object fileObj = s3Client.getObject(new GetObjectRequest(bucket, object.getKey(), null));
      try {
        logger.info("Saving file "+ fileObj.getKey());
        saveFile(fileObj);
      } catch (IOException e) {
        logger.error("Error saving file", e);
      }
      logger.info("Done");
    }
    
  }  
  
  public static void main(String[] args) throws IOException {
    ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    S3Download downloader = new S3Download();
    scheduler.scheduleAtFixedRate(downloader, 10, 10, TimeUnit.SECONDS);
    }
}

