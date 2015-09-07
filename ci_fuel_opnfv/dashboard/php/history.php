<!--#########################################################################-->
<!--# Copyright (c) 2015 Jonas Bjurel and others.                            -->
<!--# jonasbjurel@hotmail.com                                                -->
<!--# All rights reserved. This program and the accompanying materials       -->
<!--# are made available under the terms of the Apache License, Version 2.0  -->
<!--# which accompanies this distribution, and is available at               -->
<!--# http://www.apache.org/licenses/LICENSE-2.0                             -->
<!--#########################################################################-->
<html>
  <head>
    <title> OPNFV CI History </title>
<!--    <meta http-equiv="refresh" content="60" /> -->

  </head>
  <body>
    <p>
    <?php
       function read_history($history_file,$history_pos,$repo_path) {
          $fp = fopen($history_file, "r") or die("Unable to open file!");
          $pos = -2; // Skip final new line character (Set to -1 if not present)
          $lines = array();
          $currentLine = '';

          while (-1 !== fseek($fp, $pos, SEEK_END)) {
             $char = fgetc($fp);
             if (PHP_EOL == $char) {
                $lines[] = $currentLine;
                $currentLine = '';
             } else {
                $currentLine = $char . $currentLine;
             }
             $pos--;
          }
          list($result, $build_id, $branch, $commit_id, $ci_pipeline_time) = split('[|]', $lines[$history_pos]);
          list($dummy, $result) = split('[:]', $result);
          $result=trim($result);
          list($dummy, $build_id) = split('[:]', $build_id);
          $build_id=trim($build_id);
          list($dummy, $branch) = split('[:]', $branch);
          $branch=trim($branch);
          list($dummy, $commit_id) = split('[:]', $commit_id);
          $commit_id=substr(trim($commit_id), -10);
          list($dummy, $ci_pipeline_time) = split('[:]', $ci_pipeline_time);
          $ci_pipeline_time=substr(trim($ci_pipeline_time), -10);

          $history=array(
            "result" => $result,
            "build_id" => $build_id,
            "branch" => $branch,
            "commit_id" => $commit_id,
            "artifact_path" => "$repo_path/ci_fuel_opnfv/artifact/$branch/$build_id",
            "log" => "$repo_path/ci_fuel_opnfv/artifact/$branch/$build_id/ci.log",
            "iso" => "$repo_path/ci_fuel_opnfv/artifact/$branch/$build_id/opnfv-$build_id.iso",
            "ci_pipeline_time" => $ci_pipeline_time,
          );

          return $history;
       }

       $config_file="config.yaml";
       $config=yaml_parse_file($config_file);
       $repo_path=$config["ci_repo_path"];
       $history_file="$repo_path/ci_fuel_opnfv/result.log";

       echo "<pre>";
       echo "<table style=\"with:100%\">";
       echo "<td></td>";
       echo "<td></td>";
       echo "<td><b>[Result]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[build-id/Date/time]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[Branch]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[Commit-id]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[Staged CI-steps (B/D/T)]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[Artifact path]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[Iso]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[Log]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[CI-Pipeline duration]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[Test result overview]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[Fuel Access]:</b></td>";
       echo "<td></td>";
       echo "<td><b>[OpenStack Access]:</b></td>";

       for ($pos=0; $pos <=3; $pos++) {
          if (file_exists($history_file))
             $history=read_history($history_file,$pos,$repo_path);
          echo "<tr>";

          switch (strtok($history["result"], " ")) {
            case "SUCCESS":
              $format_opt="<font color='green'>";
              echo '<td><img src="images/thumbs-up-smiley-hi.png" height="20" width="20"></td>';
              echo "<td></td>";
            break;

            case "ERROR":
              $format_opt="<font color='red'>";
              echo '<td><img src="images/thumbs-down-smiley-md.png" height="20" width="20"></td>';
              echo "<td></td>";
            break;

            case "INFO":
              $format_opt="<font color='grey'>";
              echo '<td><img src="images/smiley-face-question.png" height="20" width="20"></td>';
              echo "<td></td>";
            break;
         }

         echo '<td>',$format_opt,' ',$history['result'],'</td>';
         echo "<td></td>";
         echo '<td>',$format_opt,' ',$history['build_id'],'</td>';
         echo "<td></td>";
         echo '<td>',$format_opt,' ',$history['branch'],'</td>';
         echo "<td></td>";
         echo '<td>',$format_opt,' ',$history['commit_id'],'</td>';
         echo "<td></td>";
         echo '<td>',$format_opt,' TBD</td>';
         echo "<td></td>";
         echo '<td>',$format_opt,' <a href="file://',$history['artifact_path'],'">Link</a></td>';
         echo "<td></td>";
         echo '<td>',$format_opt,' <a href="file://',$history['iso'],'">Link</a></td>';
         echo "<td></td>";
         echo '<td>',$format_opt,' <a href="file://',$history['log'],'">Link</a></td>';
         echo "<td></td>";
         echo '<td>',$format_opt,' ',$history['ci_pipeline_time'],'</td>';
         echo "<td></td>";
         echo '<td>',$format_opt,' TBD</td>';
         echo "<td></td>";
         if ($pos==0) {
            echo '<td>',$format_opt,'<a href="http://10.20.0.2:8000">Link</a></font></td>';
            echo "<td></td>";
            echo '<td>',$format_opt,'<a href="http://172.16.0.2:80">Link</a></font></td>';
            echo "<td></td>";
         }
         echo "</tr>";
       }
      echo "</table>";
      echo "</pre>";
    ?>
    </p>
  </body>
</html>
