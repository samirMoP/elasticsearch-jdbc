package org.xbib.elasticsearch.common.util;

import java.util.List;
import java.io.File;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.ObjectListing;
import com.amazonaws.services.s3.model.S3ObjectSummary;

public class S3Cleaner {
    
    private final static Logger logger = LogManager.getLogger("jdb.s3cleaner");
    private final String bucket = "pg2esimporter";
    private AmazonS3 s3Client;
    
    public S3Cleaner() {
      this.s3Client = AmazonS3ClientBuilder.defaultClient(); 
    }
    
    public void clean() {
      ObjectListing listing = s3Client.listObjects(bucket);
      List<S3ObjectSummary> summaries = listing.getObjectSummaries();
      for(S3ObjectSummary object:summaries) {
        s3Client.deleteObject(bucket, object.getKey());
        logger.info(object.getKey() + " deleted.");
      }
    }
    
    public static void main(String[] args) { 
      
      S3Cleaner cleaner = new S3Cleaner();
      cleaner.clean();
    }

}
