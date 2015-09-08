<!--#########################################################################-->
<!--# Copyright (c) 2015 Jonas Bjurel and others.                            -->
<!--# jonasbjurel@hotmail.com                                                -->
<!--# All rights reserved. This program and the accompanying materials       -->
<!--# are made available under the terms of the Apache License, Version 2.0  -->
<!--# which accompanies this distribution, and is available at               -->
<!--# http://www.apache.org/licenses/LICENSE-2.0                             -->
<!--#########################################################################-->
<?php
  function get_metadata($status_file, $repo_path) {
    $status_str = file_get_contents($status_file, FILE_USE_INCLUDE_PATH);
    list($status, $since) = split('[|]', $status_str);
    $status=trim($status);

    if ($status != "IDLE") {
      list($status, $since, $branch, $commit_id, $build_id,) = split('[|]', $status_str);
      $status=trim($status);
      $since=trim($since);
      $branch=trim($branch);
      $commit_id=substr(trim($commit_id), -10);
      $build_id=trim($build_id);
      $ci_status=array(
        "status" => $status,
        "since" => $since,
        "build_id" => $build_id,
        "commit_id" => $commit_id,
        "branch" => $branch,
        "ci_repo_path" => $repo_path,
        "artifact_path" => "$repo_path/ci_fuel_opnfv/artifact/$branch/$build_id",
        "iso" => "$repo_path/ci_fuel_opnfv/artifact/$branch/$build_id/opnfv-$build_id.iso",
         "log" => "$repo_path/ci_fuel_opnfv/artifact/$branch/$build_id/ci.log",
         "result_smoke" => "nil",
         "result_tempest" => "nil",
         "result_rally" => "nil",
          "result_odl" => "nil",
          "result_vping" => "nil",
        );
      } else {
        $ci_status=array(
        "status" => $status,
         "since" => $since,
         "build_id" => "nil",
         "commit_id" => "nil",
         "branch" => "nil",
         "ci_repo_path" => "nil",
         "artifact_path" => "nil",
         "iso" => "nil",
         "log" => "nil",
         "result_smoke" => "nil",
         "result_tempest" => "nil",
         "result_rally" => "nil",
         "result_odl" => "nil",
         "result_vping" => "nil",
       );
     }
     return $ci_status;
   }
?>