create_renv_for_dev <- function(path=".",
  dev_pkg = c("renv","devtools", "roxygen2", "usethis", "pkgload",
  "testthat", "covr", "attachment","pak","dockerfiler",
  "remotes::install_github('ThinkR-open/checkhelper')"),
  folder_to_include = c("dev/","data-raw/"),
  output = "renv.lock"
  ){

  from_r_script <-   file.path(path,folder_to_include) %>%
    map(attachment::att_from_rscripts) %>%
    unlist()


  from_rmd <-   file.path(path,folder_to_include) %>%
    map(attachment::att_from_rmds)%>%
    unlist()


  pkg_list <- c(
    attachment::att_from_description(),
    from_r_script,from_rmd,
    dev_pkg
  )
  pkg_list

  attachment::install_if_missing(pkg_list)
  cli::cli_bullets(glue::glue("create renv.lock at {output}"))
  renv::snapshot(packages = pkg_list,lockfile = output,prompt = FALSE)

 output

}
create_renv_for_prod <-function(path=".",output = "renv.lock.prod"){
  create_renv_for_dev(path = path,dev_pkg = NULL,folder_to_include=NULL,output = output)
}


lock_file_prod <-create_renv_for_prod()
create_renv_for_dev()

socle <- dock_from_renv(lockfile = lock_file_prod,
                                     distro = "focal",
                                     FROM = "rocker/verse",repos = "https://cran.rstudio.com"
)

socle
socle$write(as = file.path(output, "Dockerfile_socle"))

my_dock <- Dockerfile$new(FROM = paste0(golem::get_golem_name(),"_socle"))
my_dock$COPY(from = "renv.lock.prod.dock",to = "renv.lock")
my_dock$RUN(r(renv::restore()))
my_dock$COPY(from = paste0(golem::get_golem_name(), "_*.tar.gz"), to = "/app.tar.gz")
my_dock$RUN("R -e 'remotes::install_local(\"/app.tar.gz\",upgrade=\"never\")'")
my_dock$RUN("rm /app.tar.gz")
my_dock$EXPOSE(3838)
my_dock$CMD(sprintf(" [\"R\", \"-e\", \"options('shiny.port'=3838,shiny.host='0.0.0.0');%s::run_app()\"]",
                    golem::get_golem_name()))
my_dock
my_dock$write(as = file.path(output, "Dockerfile"))
devtools::build(pkg = ".",path = output)
out <- glue::glue("docker build -f Dockerfile_socle -t {paste0(golem::get_golem_name(),'_socle')} .
           docker build -f Dockerfile -t {paste0(golem::get_golem_name(),':latest')} .")
cat(out,file = file.path(output, "README"))







install.packages("renv")
output <- file.path("dev","bundle_deploiement")
dir.create(output,recursive = TRUE)
renv::activate()
renv::install("attachment")
renv::install("devtools")
renv::install("remotes")
remotes::install_github("colinfay/dockerfiler@24-allow_sysreq_error")
attachment::install_from_description()
# attachment::att_from_description()
prod_and_dev_packages <- c(
  attachment::att_from_description(),
  # attachment::att_from_rscripts(path = "data-raw/"),
  attachment::att_from_rscripts(path = "dev/"),
  # attachment::att_from_rmds(path = "data-raw/"),
  "renv",
  "devtools", "roxygen2", "usethis", "pkgload",
  "testthat", "covr", "attachment","pak","dockerfiler",
  # remotes::install_github("ThinkR-open/checkhelper")
  # "pkgdown",
  # "styler",
  # "checkhelper",
  "remotes" #,# "fusen",
  # remotes::install_github("ThinkR-open/thinkrtemplate")
  # "thinkrtemplate"
)
attachment::install_if_missing(prod_and_dev_packages)
renv::snapshot(packages = prod_and_dev_packages,lockfile = "renv.lock")
prod_packages <- c(
  attachment::att_from_description(),
  # attachment::att_from_rscripts(path = "data-raw/"),
  # attachment::att_from_rscripts(path = "dev/"),
  # attachment::att_from_rmds(path = "data-raw/"),
  # "renv",
  # "devtools", "roxygen2", "usethis", "pkgload",
  # "testthat", "covr", "attachment",
  # remotes::install_github("ThinkR-open/checkhelper")
  # "pkgdown",
  # "styler",
  # "checkhelper",
  "remotes" #,# "fusen",
  # remotes::install_github("ThinkR-open/thinkrtemplate")
  # "thinkrtemplate"
)
renv::snapshot(packages = prod_packages,lockfile = file.path(output,"renv.lock.prod"))
# debugonce(dock_from_renv)
# dock_from_renv ne devrait copier que le basename de lockfile
file.copy(from = file.path(output,"renv.lock.prod"),to = "renv.lock.prod",overwrite = TRUE,recursive = TRUE)
socle <- dockerfiler::dock_from_renv(lockfile = "renv.lock.prod",
                                     distro = "focal",
                                     FROM = "rocker/verse",repos = "https://cran.rstudio.com"
)
library(dockerfiler)
file.copy(from = "renv.lock.prod.dock",to = file.path(output,"renv.lock.prod.dock"),overwrite = TRUE,recursive = TRUE)
unlink("renv.lock.prod")
unlink("renv.lock.prod.dock")
socle
socle$RUN("rm -rf /var/lib/apt/lists/*")
socle$write(as = file.path(output, "Dockerfile_socle"))
my_dock <- Dockerfile$new(FROM = paste0(golem::get_golem_name(),"_socle"))
my_dock$COPY(from = "renv.lock.prod.dock",to = "renv.lock")
my_dock$RUN(r(renv::restore()))
my_dock$COPY(from = paste0(golem::get_golem_name(), "_*.tar.gz"), to = "/app.tar.gz")
my_dock$RUN("R -e 'remotes::install_local(\"/app.tar.gz\",upgrade=\"never\")'")
my_dock$RUN("rm /app.tar.gz")
my_dock$EXPOSE(3838)
my_dock$CMD(sprintf(" [\"R\", \"-e\", \"options('shiny.port'=3838,shiny.host='0.0.0.0');%s::run_app()\"]",
                    golem::get_golem_name()))
my_dock
my_dock$write(as = file.path(output, "Dockerfile"))
devtools::build(pkg = ".",path = output)
out <- glue::glue("docker build -f Dockerfile_socle -t {paste0(golem::get_golem_name(),'_socle')} .
           docker build -f Dockerfile -t {paste0(golem::get_golem_name(),':latest')} .")
cat(out,file = file.path(output, "README"))
